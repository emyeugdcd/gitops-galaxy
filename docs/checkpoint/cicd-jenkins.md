# CHECKPOINT: CI/CD Pipeline & Jenkins Operations

This checkpoint file covers containerized CI/CD operations, Jenkins agent provisioning, multi-stage Docker builds, container escape security, and Kaniko daemonless image builders.

---

### 1. How does Jenkins run ephemeral build agents dynamically inside a Kubernetes cluster?
* **Answer**: 
  1. The Jenkins master pod is configured with the Kubernetes plugin.
  2. When a pipeline build is triggered, Jenkins calls the Kubernetes API Server to launch a temporary Pod containing the build tools (Trivy, Kaniko, Go, Node) in the target namespace.
  3. The pipeline execution stages run inside the container layers of this temporary agent pod.
  4. Once the pipeline finishes (succeeds or fails), Jenkins automatically deletes the agent pod, freeing up cluster resources.

### 2. Why is mounting `/var/run/docker.sock` inside a CI/CD build pod considered a critical security vulnerability?
* **Answer**: Mounting the host's `/var/run/docker.sock` gives the build container root access to the host node's Docker daemon. A developer or attacker who runs code inside the build pipeline can execute Docker command commands (e.g. `docker run -v /:/host alpine`) to mount the physical node's root filesystem, escape the container boundary, modify node system configs, and fully compromise the cluster infrastructure.

### 3. What is Kaniko, and how does it solve this container escape vulnerability?
* **Answer**:
  * **Kaniko** is an open-source tool developed by Google to build container images from a Dockerfile inside a container or Kubernetes cluster **without relying on a Docker daemon**.
  * **How it works**: Kaniko runs as user-space code. It unpacks the base image filesystem in memory, runs each command in the Dockerfile, takes snapshots of user-space filesystem changes, and pushes the compiled layers directly to the registry. Because it does not require a running docker socket, it eliminates the need to mount `/var/run/docker.sock`.

### 4. Explain the benefits of a Multi-stage Dockerfile build.
* **Answer**:
  * **Size Reduction**: Separates the compile-time dependencies (e.g. compilers, SDKs, build packages) from the run-time requirements. You compile your application in a heavy builder stage (e.g., `golang:1.24-alpine`) and copy only the compiled binary to a lightweight base stage (e.g. `alpine:latest`).
  * **Security Hardening**: The final production container does not contain compilers, package managers, or raw source code. This minimizes the image's attack surface, leaving attackers with no system binaries to exploit if the container is compromised.
  * **Caching Efficiency**: Allows caching of individual stages (like caching packages download steps) to speed up sequential build loops.
