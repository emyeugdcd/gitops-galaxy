# CHECKPOINT: Helm Charts & Templating

This checkpoint file covers Helm packaging, template rendering, chart versioning, values mappings, and release management.

---

### 1. Why is Helm referred to as the "Kubernetes Package Manager"?
* **Answer**: Helm bundles collection of Kubernetes manifests (Deployments, Services, ConfigMaps, Ingresses) into a single, version-controlled unit called a **Chart**. It provides:
  * **Dry-Run Templating**: Standardizes configurations with variables, loops, and conditional flags.
  * **Release Tracking**: Rolls out versions atomically and handles rollback operations cleanly.
  * **Dependency Management**: Allows charts to inherit other subcharts (e.g. including a Postgres subchart inside a backend chart).

### 2. Distinguish between `version` and `appVersion` inside `Chart.yaml`.
* **Answer**:
  * **`version` (Chart Version)**: A SemVer string representing the version of the Helm templates themselves. If you change a port mapping, add a values default, or edit a deployment layout, you increment this version.
  * **`appVersion` (App Version)**: Represents the version of the actual application code inside the container (e.g. the backend git tag/version like `v2.1.0`). It has no impact on Helm's package version logic.

### 3. How does Helm keep track of release states internally, and how does it compare to Terraform?
* **Answer**:
  * **Helm**: Stores its release history and state directly inside the Kubernetes cluster as encrypted **Secrets** (or ConfigMaps) in the namespace where the release was deployed. It does not maintain external state files.
  * **Terraform**: Relies on a state file (`terraform.tfstate`) that must be stored externally (e.g., in AWS S3 or HashiCorp Consul) to map code resources to real infrastructure.

### 4. What is the difference between `helm template` and `helm install --dry-run`?
* **Answer**:
  * **`helm template`**: A client-side compile command. It renders template variables locally on your machine and outputs the raw manifests. It does not contact the Kubernetes cluster or validate resource schemas.
  * **`helm install --dry-run`**: Contact the Kubernetes API Server. It renders the manifests and sends them to the API Server for dry-run schema validation (ensuring namespaces, CRDs, and configurations are correct) without creating the actual resources.

### 5. What are Helm Hooks, and what is a common use case?
* **Answer**: Helm Hooks allow chart developers to run specific actions at defined points in a release lifecycle (e.g. `pre-install`, `post-upgrade`, `pre-delete`).
  * *Use Case*: Running a database migration Job (`pre-upgrade`) before the new backend application deployment pods boot up, ensuring schema compatibility.
