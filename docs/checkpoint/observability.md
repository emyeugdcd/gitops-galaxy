# CHECKPOINT: Cluster Observability, Logging & Alerting

This checkpoint file covers metrics collection, ServiceMonitor scrape routing, PromQL alerting expressions, log aggregation configurations, and memory debugging patterns in ELK/EFK stacks.

---

### 1. Explain how the Prometheus Operator discovers targets dynamically using `ServiceMonitor` resources.
* **Answer**: 
  1. The Prometheus Operator manages a `Prometheus` Custom Resource (CR) which uses `serviceMonitorSelector` to filter for allowed labels.
  2. Developers deploy a `ServiceMonitor` pointing to a namespace and label selector (e.g. `matchLabels: app: vitals-backend`).
  3. The Prometheus Operator watches for this `ServiceMonitor`, queries the cluster for `Services` matching those labels, retrieves their backing pod IP endpoints, and dynamically updates Prometheus's scraper configuration file (`prometheus.yaml`) without requiring a manual service restart.

### 2. How does the Prometheus alerting flow work, from PromQL validation to user notification?
* **Answer**:
  1. **Evaluation**: Prometheus evaluates alert rules defined in `PrometheusRule` manifests periodically (e.g., every 30 seconds).
  2. **Pending**: If an alert expression (e.g., `NodeCPUUsageHigh`) evaluates to true, the alert enters a `Pending` state for the duration specified in the `for` field.
  3. **Firing**: If the condition remains true for the entire `for` duration, the alert transitions to `Firing` and is sent to **Alertmanager**.
  4. **Routing & Notification**: Alertmanager dedupes, groups, and silences the alerts based on routing policies, then forwards notifications to target endpoints (Slack, Email, PagerDuty).

### 3. What is the role of Fluent Bit in log aggregation, and how does it extract container logs?
* **Answer**: Fluent Bit runs as a cluster-wide **DaemonSet** (one pod per node).
  * It mounts the host node's container log directory: `/var/log/containers/` (which gathers the stdout/stderr stream from the container runtime).
  * It reads log lines, attaches Kubernetes metadata (pod name, namespace, container name) by querying the local Kubelet API, parses the JSON streams, and ships the logs to **Elasticsearch** for indexing.

### 4. Why did Elasticsearch crash with exit code `137` in our local cluster, and how did we resolve it?
* **Answer**:
  * **Cause**: Elasticsearch runs on Java. Java apps use both their JVM Heap (`-Xms`/`-Xmx` values) and native memory (buffers, file mappings). If the container limit is set too low (e.g., `512Mi`), the JVM overhead combined with Elasticsearch operations will exceed the container memory limit, prompting the host kernel OOM killer to terminate it with exit code `137`.
  * **Fix**:
    1. Adjusted [elasticsearch.yaml](../../cluster-chronicles/manifests/elasticsearch.yaml) to increase the container memory limit to `1Gi`.
    2. Restricted the JVM options heap allocation environment variables (e.g. `ES_JAVA_OPTS="-Xms256m -Xmx256m"`) to leave enough headroom for the container runtime.

### 5. Why are alerts like `Watchdog`, `etcdMembersDown`, and `TargetDown` firing by default in a local Minikube cluster?
* **Answer**:
  * **Watchdog**: Firing by design. It continuously tests the end-to-end alert notification channel. If it stops firing, it means your alerting pipeline is broken.
  * **etcd / TargetDown**: Minikube is a single-node cluster. Its core control plane components (etcd, scheduler, controller-manager) bind metrics to localhost (`127.0.0.1`) inside the VM to protect them. The default community Prometheus stack expects a production multi-node cluster with exposed control plane ports, so it raises alerts because it cannot scrape those unreachable loopback addresses.
