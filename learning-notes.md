# GitOps Galaxy: Helm & ArgoCD Study Notes

This guide compiles the key theoretical frameworks, configuration syntax, and architectural concepts behind package management and declarative GitOps continuous delivery.

---

## ⛵ Part 1: Helm Architecture & Templating Mechanics

### 1. What is Helm?
Helm is the package manager for Kubernetes. Instead of maintaining static, duplicate YAML manifests across different namespaces or environments (dev, staging, production), Helm bundles them into a reusable template package called a **Chart**.

### 2. Helm Chart Structure
A standard Helm Chart contains the following folders and files:
* **`Chart.yaml`**: Contains metadata about the chart (e.g., chart name, description, apiVersion, chart version, and application version).
* **`values.yaml`**: The default configuration variables for the chart. Users override these parameters during deployment.
* **`templates/`**: The folder containing Kubernetes manifests containing templating bracket syntax.
* **`templates/_helpers.tpl`**: Helper templates and named templates (macros) used to generate repeated labels or names across multiple resources.
* **`charts/`**: Optional folder containing sub-charts that this chart depends on.

### 3. Basic Templating Syntax
Helm uses the Go template language. Bracket syntax `{{ ... }}` is replaced by compiled values during execution:
* **Scope (`.`)**: Represents the current root context.
* **Values Mapping**: Access parameters from `values.yaml` using `{{ .Values.path.to.variable }}`.
* **Pipelines & Functions**:
  * `quote`: Wraps the output in double quotes: `{{ .Values.namespace | quote }}`.
  * `toString`: Converts a value to string type.
  * `b64enc`: Base64 encodes string values (essential for `Secrets` generation):
    ```yaml
    BACKEND_PORT: {{ .Values.backend.service.port | toString | b64enc | quote }}
    ```
* **Control Flows (Conditionals)**:
  * `if / end`: Selective rendering blocks:
    ```yaml
    {{- if .Values.ingress.enabled -}}
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    ...
    {{- end -}}
    ```
  * Note the hyphens `{{-` and `-}}`. They trim trailing and leading whitespaces/newlines from the compiled YAML output, preventing indentation formatting issues.

---

## 🐙 Part 2: GitOps continuous delivery (ArgoCD)

### 1. GitOps Core Principles
GitOps is an operational model where the **Git repository is the single source of truth** for your infrastructure and application states.
1. **Declarative State**: The infrastructure is described declaratively in files (YAMLs / Helm Charts).
2. **Versioned & Immutable**: The desired state is stored in Git, keeping a clear history of modifications, author audits, and easy rollback.
3. **Automated Pull Reconciler**: An agent running *inside* the cluster continuously polls Git and synchronizes cluster resources to match the repository.

### 2. Push vs. Pull CI/CD Architecture
DevOps teams transition from traditional push pipelines to pull-based GitOps loops:

| Feature | Push-Based (e.g., Jenkins / GitLab CI direct deployment) | Pull-Based (e.g., ArgoCD GitOps) |
| :--- | :--- | :--- |
| **Execution Path** | CI Runner connects to Kubernetes API server externally and runs `kubectl apply`. | Reconciler agent runs *inside* the cluster, polling Git and applying states internally. |
| **Credentials Security**| CI Runner requires administrator Kubeconfig credentials. If CI is compromised, the cluster is exposed. | No cluster credentials leave the cluster. The CI only needs access to push to Git. |
| **Firewall Control** | Requires opening cluster api-server port (6443) to the internet or CI runners. | Cluster is completely closed. Reconciler makes outbound queries to Git. |
| **Drift Management** | Does not detect manual changes. If someone edits a pod manually, drift remains. | Actively checks live state against Git and automatically overrides manual drift. |

### 3. Sync Policies & Safety Options
ArgoCD applications use specific sync policies to manage deployments:
* **Prune**: If you delete a manifest file from your Git repository, ArgoCD automatically deletes that resource from your Kubernetes cluster. Without this, deleted files would remain as "orphaned" resources in the cluster.
* **Self-Heal**: If a developer runs a manual `kubectl edit` command or a script modifies a service configuration, ArgoCD immediately detects the discrepancy, marks the app `OutOfSync`, and rewrites the resource back to the desired Git state.
* **CreateNamespace**: Automatically creates the destination namespace if it does not already exist in the cluster.
* **ApplyOutOfSyncOnly**: Optimizes performance. Instead of running a full apply on all resources in the chart, ArgoCD only patches those resources whose specifications have drifted.
