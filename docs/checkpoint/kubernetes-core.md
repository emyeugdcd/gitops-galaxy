# CHECKPOINT: Kubernetes Core Concepts

This checkpoint file covers the internal components, controller patterns, resource limits, routing, and workload management patterns of Kubernetes.

---

### 1. Describe the role of the five primary components of the Kubernetes Control Plane.
* **Answer**:
  * **kube-apiserver**: The central hub. Exposes the REST API, validates manifests, and acts as the entry point for all operations.
  * **etcd**: The cluster's distributed key-value store. Holds the single source of truth for cluster state and config.
  * **kube-scheduler**: Assigns pods to nodes based on resource demands, constraints, and affinity rules.
  * **kube-controller-manager**: Runs controllers that regulate the state of the cluster (Node Controller, Job Controller, Deployment Controller) to match actual state with desired state.
  * **cloud-controller-manager** (Optional): Integrates with cloud provider APIs to manage storage, networking, and node lifecycles.

### 2. What is the difference between a Deployment and a StatefulSet, and when is each appropriate?
* **Answer**:
  * **Deployment**: Exposes stateless workloads. Pods get random, ephemeral hostnames (e.g. `web-1a2b3c`) and share storage volumes indiscriminately. Used for microservices, SPAs, and APIs.
  * **StatefulSet**: Exposes stateful workloads. Pods get stable, ordinal names (e.g. `db-0`, `db-1`) that persist across restarts. Each pod binds to a dedicated Persistent Volume (PV) via a claim template. Used for database clusters (PostgreSQL, Elasticsearch) and queue managers.

### 3. Explain the differences between Liveness, Readiness, and Startup Probes.
* **Answer**:
  * **Startup Probe**: Runs first. Determines if the application inside the container has booted. Disables liveness and readiness checks until it succeeds, preventing slow-starting apps from crash-looping.
  * **Liveness Probe**: Determines if the container needs a restart. If it fails, kubelet kills the container and triggers its restart policy.
  * **Readiness Probe**: Determines if the pod is ready to serve network traffic. If it fails, the pod's IP is removed from all matching Service Endpoints.

### 4. What happens when a container exceeds its CPU limit versus its Memory limit?
* **Answer**:
  * **CPU limit**: CPU is a compressible resource. If a container exceeds its CPU limit, Kubernetes throttles the container's CPU allocation. It will run slower, but the process will not be terminated.
  * **Memory limit**: Memory is a non-compressible resource. If a container exceeds its memory limit, the host kernel triggers the Out-of-Memory (OOM) killer, terminates the process, and the pod restarts with exit code `137` (`OOMKilled`).

### 5. Contrast ClusterIP, NodePort, and LoadBalancer Service types.
* **Answer**:
  * **ClusterIP**: Exposes the service on a cluster-internal IP. Reachable only from within the cluster. (Default type; e.g. databases, internal services).
  * **NodePort**: Exposes the service on each Node's IP at a static port (range `30000-32767`). Redirects external requests to the cluster-internal service.
  * **LoadBalancer**: Integrates with cloud providers to automatically provision a physical Load Balancer (like AWS NLB/ALB) pointing to the NodePort.
