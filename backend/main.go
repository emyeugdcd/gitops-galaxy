package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
)

var (
	cpuUsageGauge = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "app_cpu_usage_percent",
		Help: "Current CPU usage percentage read from /proc/stat",
	})
	memUsedGauge = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "app_memory_used_mb",
		Help: "Current memory used in MB read from /proc/meminfo",
	})

	cpuMutex       sync.RWMutex
	cachedCPUUsage float64
)

func updatePrometheusMetrics() {
	for {
		cpuVal := getCPUUsage()
		cpuUsageGauge.Set(cpuVal)

		cpuMutex.Lock()
		cachedCPUUsage = cpuVal
		cpuMutex.Unlock()

		_, used, _ := getMemory()
		memUsedGauge.Set(float64(used))
		time.Sleep(5 * time.Second)
	}
}

type Metrics struct {
	Hostname   string    `json:"hostname"`
	OS         string    `json:"os"`
	KernelInfo string    `json:"kernel_info"`
	Uptime     string    `json:"uptime"`
	CPUModel   string    `json:"cpu_model"`
	CPUCores   int       `json:"cpu_cores"`
	CPUUsage   float64   `json:"cpu_usage_percent"`
	MemTotal   uint64    `json:"mem_total_mb"`
	MemUsed    uint64    `json:"mem_used_mb"`
	MemPercent float64   `json:"mem_used_percent"`
	GoVersion  string    `json:"go_version"`
	Timestamp  time.Time `json:"timestamp"`
}

// Reads /proc/uptime — first field is seconds since boot
func getUptime() string {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return "unknown"
	}
	parts := strings.Fields(string(data))
	if len(parts) == 0 {
		return "unknown"
	}
	totalSeconds, _ := strconv.ParseFloat(parts[0], 64)
	h := int(totalSeconds) / 3600
	m := (int(totalSeconds) % 3600) / 60
	return fmt.Sprintf("%dh %dm", h, m)
}

// Reads /proc/cpuinfo — looks for "model name" field
func getCPUModel() string {
	f, err := os.Open("/proc/cpuinfo")
	if err != nil {
		return "unknown"
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "model name") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) == 2 {
				return strings.TrimSpace(parts[1])
			}
		}
	}
	return "unknown"
}

// Measures CPU usage by sampling /proc/stat twice with a short sleep between.
// /proc/stat gives cumulative CPU ticks — the difference between two reads
// tells us how busy the CPU was in that window.
func getCPUUsage() float64 {
	read := func() (idle, total uint64) {
		data, err := os.ReadFile("/proc/stat")
		if err != nil {
			return 0, 0
		}
		line := strings.SplitN(string(data), "\n", 2)[0] // first line: "cpu  ..."
		fields := strings.Fields(line)[1:]               // drop the "cpu" label
		var vals [10]uint64
		for i, f := range fields {
			if i >= 10 {
				break
			}
			vals[i], _ = strconv.ParseUint(f, 10, 64)
		}
		// Fields: user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice
		idle = vals[3] + vals[4] // idle + iowait
		for _, v := range vals {
			total += v
		}
		return
	}

	idle1, total1 := read()
	time.Sleep(500 * time.Millisecond)
	idle2, total2 := read()

	idleDelta := float64(idle2 - idle1)
	totalDelta := float64(total2 - total1)
	if totalDelta == 0 {
		return 0
	}
	return (1 - idleDelta/totalDelta) * 100
}

// Reads /proc/meminfo — parses MemTotal and MemAvailable
func getMemory() (total, used uint64, percent float64) {
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return
	}
	defer f.Close()

	values := make(map[string]uint64)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		parts := strings.Fields(scanner.Text())
		if len(parts) >= 2 {
			val, _ := strconv.ParseUint(parts[1], 10, 64)
			values[strings.TrimSuffix(parts[0], ":")] = val
		}
	}

	totalKB := values["MemTotal"]
	availKB := values["MemAvailable"]
	usedKB := totalKB - availKB

	total = totalKB / 1024
	used = usedKB / 1024
	if totalKB > 0 {
		percent = float64(usedKB) / float64(totalKB) * 100
	}
	return
}

// Reads /proc/version for kernel info
func getKernelInfo() string {
	data, err := os.ReadFile("/proc/version")
	if err != nil {
		return "unknown"
	}
	// Just grab the first meaningful part
	fields := strings.Fields(string(data))
	if len(fields) >= 3 {
		return fmt.Sprintf("Linux %s", fields[2])
	}
	return strings.TrimSpace(string(data))
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	hostname, _ := os.Hostname()
	memTotal, memUsed, memPercent := getMemory()

	cpuMutex.RLock()
	currentCPU := cachedCPUUsage
	cpuMutex.RUnlock()

	metrics := Metrics{
		Hostname:   hostname,
		OS:         runtime.GOOS,
		KernelInfo: getKernelInfo(),
		Uptime:     getUptime(),
		CPUModel:   getCPUModel(),
		CPUCores:   runtime.NumCPU(),
		CPUUsage:   currentCPU,
		MemTotal:   memTotal,
		MemUsed:    memUsed,
		MemPercent: memPercent,
		GoVersion:  runtime.Version(),
		Timestamp:  time.Now().UTC(),
	}

	json.NewEncoder(w).Encode(metrics)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, `{"status":"ok"}`)
}

func main() {
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.SetOutput(os.Stdout)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	go updatePrometheusMetrics()

	http.HandleFunc("/metrics", metricsHandler)
	http.Handle("/prometheus", promhttp.Handler())
	http.HandleFunc("/health", healthHandler)

	logrus.WithFields(logrus.Fields{
		"port": port,
	}).Info("Backend running")
	logrus.Fatal(http.ListenAndServe(":"+port, nil))
}
