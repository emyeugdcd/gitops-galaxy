# DevOps & GitOps Checkpoint Exam: Interview Prep & Study Guide

I use this checkpoint directory to test my knowledge, prepare for technical interviews, and consolidate my foundation in Helm, ArgoCD, and cluster operations. These are the questions I asked AI to test me and then I tried to answer them myself, afterwards asking AI to grade my answers and suggest improvements.

## Categorized Checkpoint Question Collections

To test specific domains of Kubernetes, GitOps, CI/CD, and monitoring, explore the sub-topic checkpoint guides in the [checkpoint](./checkpoint) directory:

* **[Big Picture Architecture](./checkpoint/big-picture.md)**: System design and macro architecture patterns.
* **[Kubernetes Core Concepts](./checkpoint/kubernetes-core.md)**: Pod lifecycle, services, storage, and orchestration components.
* **[GitOps & ArgoCD](./checkpoint/gitops-argocd.md)**: Pull-based continuous delivery and sync strategies.
* **[Helm Charts & Templating](./checkpoint/helm-charts.md)**: Packaging, variable mapping, and release tracking.
* **[Observability & Alerts](./checkpoint/observability.md)**: Prometheus monitoring, logs pipeline (EFK), and alert trigger management.
* **[CI/CD & Jenkins Operations](./checkpoint/cicd-jenkins.md)**: Ephemeral agents, Docker builds, and security scans.
* **[Security & RBAC](./checkpoint/security-rbac.md)**: Roles, bindings, network policies, and secret management.

---

## Part 1: Scenario-Based Questions

### Scenario 1: The Quota Blockade
**Q**: You attempt to run `kubectl apply -f app-pod.yaml` but get the error:
`Error from server (Forbidden): pods "vitals-frontend-xxx" is forbidden: failed quota: vitals-quota: must specify limits.cpu`
What does this mean, and what is the fix?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: The namespace has a `ResourceQuota` enforced that mandates **every single container** must declare CPU and Memory requests and limits. If a pod manifest omits these parameters, the Kubernetes API Server immediately rejects it before scheduling.
* **Fix**: Update the pod's container specifications to include a `resources` block with `requests` and `limits`:
  ```yaml
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
  ```
</details>

---

### Scenario 2: The Git HEAD Resolution Failure
**Q**: When connecting a newly initialized Git repository to ArgoCD, you see the error:
`ComparisonError: unable to resolve 'HEAD' to a commit SHA`
Why did this happen, and how do you resolve it?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: Git initializes a bare repository with the default branch set to `master`. If you pushed your local code to a branch named `main`, the remote's `HEAD` reference is still pointing to `refs/heads/master` (which does not exist on the server), making HEAD unresolvable.
* **Fix**:
  1. Update the default branch symbolic reference inside the Git server:
     `git symbolic-ref HEAD refs/heads/main`
  2. Or edit the ArgoCD Application manifest's `targetRevision` from `HEAD` to point explicitly to `main`.
</details>

---

### Scenario 3: The Flapping Autoscaler
**Q**: You deploy a Horizontal Pod Autoscaler (HPA) targeting 20% CPU utilization. You notice that the cluster replica count is constantly jumping from 2 to 5 and back to 2 every couple of minutes, causing performance instability. What is this phenomenon called, and how do you resolve it?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: This is called **Flapping** (or Thrashing). It occurs when the scaling threshold is set too close to the baseline workload. When traffic spikes slightly, HPA scales up. Because new pods share the load, average CPU instantly drops below 20%, causing HPA to scale down. As soon as pods scale down, CPU spikes again, triggering another scale-up.
* **Fix**: 
  1. Increase the CPU utilization target to a stable production threshold (typically between **50% and 70%**).
  2. Configure HPA's `behavior` block to define cooldown periods (e.g., `stabilizationWindowSeconds` during scale-down) to slow down replica deletion.
</details>

---

### Scenario 4: The Push vs. Pull Paradigm
**Q**: During a job interview, the interviewer asks: *"Why should we use ArgoCD (Pull model) instead of triggering kubectl apply from GitLab CI runners (Push model)?"* State three key security/operational arguments.
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**:
  1. **Credential Security**: In a push model, GitLab CI must store your cluster administrator credentials (Kubeconfig keys) to run commands. In a pull model, credentials stay inside the cluster; ArgoCD runs internally and only needs read-access to Git.
  2. **Drift Detection**: GitLab CI runs once and finishes. If a developer manually modifies a cluster resource, GitLab CI will not know. ArgoCD continuously runs a reconciliation loop, automatically correcting manual drift.
  3. **Cluster Isolation**: You do not need to open inbound port access (6443) on your Kubernetes API Server for external CI runners; the cluster can remain fully closed within a private network.
</details>

---

### Scenario 5: The Phantom Browser Mismatch (DNS vs. Ingress Routing)
**Q**: You deploy a Single Page Application (SPA) frontend and a backend API on Kubernetes. Internal pod-to-pod networking is healthy (`wget` from frontend pod to backend pod returns 200). The frontend HTML template loads on your host browser, but all browser API requests to the backend return `net::ERR_NAME_NOT_RESOLVED`. Why did this happen and how do you fix it?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: An SPA's JavaScript runs client-side inside the **end-user's host browser**, not inside the cluster pods. If the frontend configuration points to the internal Kubernetes DNS name (`http://vitals-backend-service:8080/metrics`), the client's host browser will try to resolve this internal name and fail, as it has no DNS path into the cluster network.
* **Fix**:
  1. Add a rule to your cluster Ingress to expose the backend API service on a path (e.g. `vitals.local/api`) or map a specific hostname (e.g. `vitals-backend-service`).
  2. Configure your local host `/etc/hosts` file (or DNS server) to map that domain to your local Kubernetes Ingress IP (e.g. `127.0.0.1` for port-forwarded Nginx Controller).
  3. Update the frontend application configuration to request the API through this exposed external URL.
</details>

---

### Scenario 6: The Invisible Vulnerabilities (Go Builder CVEs)
**Q**: A Trivy scan of your application's base container image (Alpine) shows 0 OS vulnerabilities, but a scan of your compiled application binary inside the image shows 15 High/Critical CVEs. How is this possible when the host OS is clean, and how do you resolve it?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: Trivy scans both OS system libraries (via package managers like apk/apt) and compiled language runtimes (like Go, Node, Python libraries). Even if your final image OS (Alpine) is clean, vulnerabilities in Go standard library packages (like `net/http` or `crypto/tls`) are compiled directly into your static binary. These vulnerabilities are inherited from the **Docker Builder stage image** (e.g., `golang:1.23-alpine`) used to compile the code.
* **Fix**: Upgrade the builder image in your multi-stage `Dockerfile` (e.g., from `golang:1.23-alpine` to a patched version like `golang:1.24-alpine`) and recompile the binary. This ensures the binary is compiled with a secure and patched version of the language's standard libraries.
</details>

---

### Scenario 7: The Scraper Silent Drop (Prometheus discovery failure)
**Q**: You deploy a `ServiceMonitor` to scrape metrics from a backend service, but your custom dashboards in Grafana display "No Data". Running a test query to Prometheus returns no metrics. How can you programmatically diagnose if the target service is being discovered by Prometheus, and what is the typical root cause?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: You can check Prometheus's active targets list by running a temporary Python debug container directly in the cluster to query the Prometheus target discovery API:
  ```bash
  kubectl run tmp-python-pod --image=python:3.9-alpine -n monitoring --restart=Never --rm -i -- python -c '
  import urllib.request, json
  req = urllib.request.urlopen("http://prometheus-kube-prometheus-prometheus.monitoring.svc:9090/api/v1/targets")
  data = json.loads(req.read().decode())
  for t in data["data"]["droppedTargets"]:
      print("Dropped:", t.get("discoveredLabels"))
  '
  ```
* **Root Cause**: If the target service is listed in `droppedTargets`, it means Prometheus discovered the service but ignored it. The most common cause is a **label mismatch** between the `ServiceMonitor`'s `matchLabels` selector and the `Service` metadata labels block (which is often left completely empty by mistake).
</details>

---

### Scenario 8: The Host-Shared Disk Simulation Mismatch
**Q**: You define a node disk alert to trigger if available disk space is `< 20%`. In your local Minikube cluster, you run `minikube ssh -- sudo fallocate -l 10G /large_file.img` to simulate disk consumption. The file creates successfully, but the alert never triggers, and querying the metric returns empty. Why?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: 
  1. **Mountpoint Mismatch**: Containerized Node Exporters do not mount the host root at `/` inside the container; they typically map the primary disk volume to `/data` or `/rootfs`. Using a hardcoded label filter like `{mountpoint="/"}` will return empty results.
  2. **Storage Sharing**: Under local Docker drivers, Minikube shares your host Mac's hard drive storage, reporting a total disk capacity of ~1TB. A 10GB file is only ~1% disk usage, far below the threshold needed to drop free space below 20%.
* **Fix**:
  1. Update the alert query to use a regex mountpoint filter: `mountpoint=~"/|/data"`.
  2. Use a **threshold simulation method** by temporarily editing the alert rule in `prometheus-rules.yaml` to trigger on `< 99%` and re-applying, rather than generating massive dummy files which can crash the system.
</details>

---

## Part 2: Quick-Fire Interview Flashcards

### 1. What is the difference between a Helm Chart Version and an App Version?
> **Answer**: 
> * **Chart Version** (in `Chart.yaml`): The version of the Helm templates themselves. If you change a port variable or modify values mapping, you increment the Chart Version (e.g., `1.0.1`).
> * **App Version** (in `Chart.yaml`): The version of the actual application code inside the container (e.g. `v3.4.0` of your backend).

### 2. How does a ConfigMap differ from a Secret in Kubernetes?
> **Answer**: 
> * **ConfigMap**: Holds non-sensitive configuration data in plain text.
> * **Secret**: Holds sensitive parameters (credentials, keys) encoded in Base64 (not securely encrypted by default, but blocks plain text eyes in Git).

### 3. What does "Pruning" mean in ArgoCD?
> **Answer**: If a resource manifest is deleted from the source Git repository, ArgoCD will automatically delete (prune) that resource from the live cluster, preventing orphaned workloads.

### 4. Why does HPA require resource requests in container specifications?
> **Answer**: HPA calculates pod CPU utilization as a percentage of the pod's CPU **Request** (e.g., 20m out of a 100m request). If no request is declared, HPA has no base value to divide by, resulting in `<unknown>` utilization metrics.

### 5. Why is Kaniko preferred over mounting `/var/run/docker.sock` in CI/CD pipeline builds?
> **Answer**: Mounting `docker.sock` grants the build container full root access to the host's Docker daemon. If a malicious build script runs, it can exploit container breakouts and compromise the host VM. Kaniko builds Docker images inside the container user-space without root socket access, securing the host.

### 6. What happens if you run a CPU stress test with threads equal to the node's CPU core count?
> **Answer**: It causes CPU starvation. Kubernetes control plane daemons (like `kube-apiserver`, `kubelet`, and `kube-proxy`) share the node resources with user workloads. Starving them of CPU cycles causes the node to drop connection, freeze active port-forward tunnels, and make the API server temporarily unreachable.

### 7. What is JVM heap limit configuration in Kubernetes, and why must it stay below the container limits?
> **Answer**: A container runtime kills processes (via OOMKiller) if they exceed the container's memory limits. However, the JVM heap size is not the only memory Java uses (it also needs native thread stack, Lucene indexes, metadata space). If JVM max heap (`-Xmx`) is set to the same size as the container memory limit, native memory overhead will push total usage over the cap, triggering a container OOMKilled exit code 137. The JVM heap should be kept at ~50%-75% of the container limits.
