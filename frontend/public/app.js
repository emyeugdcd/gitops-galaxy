let backendUrl = '';

async function init() {
  const config = await fetch('/config').then(r => r.json());
  backendUrl = config.backendUrl;
  document.getElementById('web-server-badge').textContent = `Web server: ${config.webServer}`;
  await fetchMetrics();

  document.getElementById('refresh-btn').addEventListener('click', fetchMetrics);
  // Auto-refresh every 10 seconds
  setInterval(fetchMetrics, 10_000);
}

async function fetchMetrics() {
  try {
    const data = await fetch(`${backendUrl}/metrics`).then(r => r.json());
    render(data);
  } catch (err) {
    document.getElementById('last-updated').textContent = 'Error fetching metrics';
  }
}

function render(d) {
  document.getElementById('val-hostname').textContent = d.hostname;
  document.getElementById('val-os').textContent = `${d.os} — ${d.kernel_info}`;
  document.getElementById('val-uptime').textContent = d.uptime;
  document.getElementById('val-go').textContent = d.go_version;

  document.getElementById('val-cpu-model').textContent = d.cpu_model;
  document.getElementById('val-cpu-cores').textContent = `${d.cpu_cores} cores`;
  document.getElementById('val-cpu-pct').textContent = `${d.cpu_usage_percent.toFixed(1)}% (BPM)`;
  document.getElementById('bar-cpu').style.width = `${d.cpu_usage_percent}%`;

  document.getElementById('val-mem-used').textContent = `${d.mem_used_mb} MB used`;
  document.getElementById('val-mem-total').textContent = `of ${d.mem_total_mb} MB`;
  document.getElementById('val-mem-pct').textContent = `${d.mem_used_percent.toFixed(1)}% (SpO2)`;
  document.getElementById('bar-mem').style.width = `${d.mem_used_percent}%`;

  document.getElementById('val-timestamp').textContent = new Date(d.timestamp).toLocaleString();
  document.getElementById('last-updated').textContent = `Auto-refreshes every 10s`;
}

init();