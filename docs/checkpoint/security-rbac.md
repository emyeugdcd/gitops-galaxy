# CHECKPOINT: Kubernetes Security & RBAC

This checkpoint file covers Role-Based Access Control (RBAC), Secrets management, least privilege principles, and network-level security isolation (NetworkPolicies).

---

### 1. Differentiate between a Role/RoleBinding and a ClusterRole/ClusterRoleBinding.
* **Answer**:
  * **Role**: Defines a set of permissions restricted to resources within a **single namespace** (e.g. read/write pods in `vitals-app`).
  * **RoleBinding**: Grants the permissions defined in a Role to a subject (User, Group, ServiceAccount) within that specific namespace.
  * **ClusterRole**: Defines permissions for cluster-scoped resources (Nodes, Namespaces, PersistentVolumes) or resource templates across all namespaces.
  * **ClusterRoleBinding**: Grants the permissions defined in a ClusterRole to a subject across the entire cluster.

### 2. How did we implement the Principle of Least Privilege for Jenkins in our pipeline?
* **Answer**:
  * We created a dedicated `ServiceAccount` called `jenkins-sa` inside the `vitals-app` namespace.
  * Instead of binding it to the cluster-admin cluster role, we created a namespace-specific `Role` that restricts Jenkins' permissions strictly to resources inside the `vitals-app` namespace (e.g., allow `create`, `update`, `patch`, `delete` on `deployments`, `pods`, `services`, `secrets`, `configmaps`).
  * We bound them using a `RoleBinding`. If the Jenkins pod is compromised, the attacker is isolated to the `vitals-app` namespace and cannot access monitoring, logging, or cluster system resources.

### 3. What is the security limitation of native Kubernetes Secrets, and how should they be hardened?
* **Answer**:
  * **Limitation**: Native Kubernetes Secrets are only **Base64 encoded** by default, not encrypted. Anyone who has API access to read Secrets or access to the Git repo containing secrets manifests can decode them instantly (`echo <secret> | base64 --decode`).
  * **Hardening Solutions**:
    1. **Encryption at Rest**: Enable kms provider encryption in the cluster `kube-apiserver` config so etcd stores Secrets encrypted.
    2. **Secret Managers**: Retrieve sensitive credentials dynamically at runtime (into memory) from dedicated secret stores (HashiCorp Vault, AWS Secrets Manager) using vault-agent init containers or CSI store drivers, rather than saving them in etcd.
    3. **Git Security**: Use tools like SOPS or SealedSecrets to encrypt secrets before committing them to version control.

### 4. Explain how a NetworkPolicy acts as a pod-level firewall.
* **Answer**:
  * By default, the Kubernetes network model allows all pods to communicate with each other freely across namespaces without constraints.
  * A `NetworkPolicy` allows you to declare ingress (incoming) and egress (outgoing) traffic rules based on pod label selectors, namespace selectors, or CIDR blocks.
  * If a policy selects a pod, all traffic to/from that pod is blocked unless it explicitly matches the declared white-list rules (e.g. allowing incoming traffic to the backend API pod *only* if the source pod carries the label `app: vitals-frontend` on port `8080`).

### 5. Why should secrets be mounted as files (volumes) rather than injected as environment variables?
* **Answer**:
  * Environment variables are easily leaked: they are printed in debug logs, visible to anybody running `kubectl describe pod`, and accessible to all child processes spawned inside the container.
  * Mounting secrets as a **volume** writes them to a temporary memory-backed filesystem (`tmpfs`). They exist only as local files which can restrict read permission (using `defaultMode`), do not get written to disk, and are automatically updated (rotated) inside the container when updated in the API server without restarting the pod.
