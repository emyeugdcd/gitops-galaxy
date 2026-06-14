# CHECKPOINT: Big Picture & System Architecture

This file compiles essential concepts regarding the macro architecture, migration paradigms, and high-level design decisions of the **Cluster Chronicles** (Kubernetes migration) and **GitOps Galaxy** (GitOps automation) stacks.

---

### 1. What is the core difference between the architecture of Sherlock Logs (VM-based VM/Ansible stack) and Cluster Chronicles (Kubernetes-native)?
* **Answer**: 
  * **Sherlock Logs** uses a virtualization layer where each component (Load Balancer, Web Server, App Server) is hosted on dedicated, heavy virtual machines (Vagrant/VirtualBox). Provisioning is imperative and configuration management (Ansible) acts on mutable OS states directly.
  * **Cluster Chronicles** uses containerization orchestrated by Kubernetes (Minikube). Workloads run in lightweight, immutable container namespaces. Network routing, high-availability replication, self-healing, and resource boundaries are managed natively by the Kubernetes control plane. Idempotency is enforced declaratively via YAML manifests, not shell scripts.

### 2. Walk through the request lifecyle from a user typing `http://vitals.local:8080` to the rendering of dashboard metrics.
* **Answer**:
  1. The browser queries local `/etc/hosts` and resolves `vitals.local` to `127.0.0.1`.
  2. The request hits the active `kubectl port-forward` running on host port `8080` and is forwarded to the cluster's `ingress-nginx-controller` Service on port `80`.
  3. The Ingress controller evaluates the routing rules in the `Ingress` manifest and routes the HTTP request to the `vitals-frontend-service` on port `3000`.
  4. The Service proxies the request to one of the healthy `vitals-frontend` pods. The pod returns static HTML/JS to the host browser.
  5. The host browser executes `app.js` (client-side). The script calls `http://vitals-backend-service:8080/metrics`.
  6. The host's `/etc/hosts` resolves `vitals-backend-service` to `127.0.0.1`, which is captured by the Ingress port-forward. The Ingress routes it to `vitals-backend-service` (Port `8080`), leading to the `vitals-backend` pod.
  7. The backend queries custom Prometheus exporter metrics and returns them as JSON. The browser renders the metrics.

### 3. How does local development cluster environments (like Minikube with Docker driver) differ from production-grade cloud environments?
* **Answer**:
  * **Compute & Nodes**: Minikube runs as a single-node cluster inside a container or VM, running control plane and user workloads together. Production uses multi-node clusters with dedicated master and worker node groups.
  * **Networking & LoadBalancers**: Minikube uses `minikube tunnel` or local host port-forwards to mimic external exposure. Production integrates directly with cloud providers (AWS, GCP) to dynamically provision physical LoadBalancers.
  * **Storage**: Minikube uses local `hostPath` directories on the VM. Production implements network-attached storage classes (EBS, Ceph, EFS) that survive node restarts and migration.

### 4. What is GitOps, and how does it reconcile configuration drift?
* **Answer**:
  * GitOps is an operational framework where **Git is the single source of truth** for declarative infrastructure and applications.
  * Configuration drift occurs when manual edits (e.g. `kubectl scale` or `kubectl edit`) are performed directly inside the cluster, making it diverge from Git.
  * GitOps tools (like ArgoCD) run a continuous reconciliation loop: they fetch target states from Git, compare them with the live cluster state, detect drift, and either alert administrators or automatically overwrite changes to match Git (self-healing).

### 5. Why do we separate the application source code repository from the GitOps infrastructure repository?
* **Answer**:
  * **Access Control**: Developers need write access to code but shouldn't have direct access to modify cluster deployment files or infrastructure parameters.
  * **Build Loop Prevention**: If code and manifests are in the same repo, compiling code, pushing an image tag change, and updating the manifest within the pipeline will trigger a recursive, infinite build loop.
  * **Environment Isolation**: A single GitOps repository can centralize manifests for multiple environments (Dev, Staging, Prod), whereas application code is agnostic of where it is deployed.
