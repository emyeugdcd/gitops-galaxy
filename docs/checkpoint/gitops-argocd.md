# CHECKPOINT: GitOps & ArgoCD Concepts

This checkpoint file covers GitOps deployment models, ArgoCD application lifecycle management, synchronization behaviors, drift detection, and deployment scale patterns.

---

### 1. Why is the Pull model (ArgoCD) fundamentally more secure than the Push model (CI-runner based)?
* **Answer**: 
  * In the **Push model**, your CI/CD runner (e.g. GitHub Actions, GitLab CI) must store the cluster's Kubeconfig containing administrative credentials. If the CI platform is breached, the cluster is compromised.
  * In the **Pull model**, ArgoCD resides inside the cluster and pulls configuration changes from Git. The cluster control plane doesn't expose public inbound ports, and no administrative API credentials ever leave the cluster.

### 2. Explain the purpose of "Prune" and "Self-Heal" settings in ArgoCD.
* **Answer**:
  * **Pruning**: If a resource file is deleted from your Git repository, ArgoCD will automatically delete that matching resource in the cluster. Without pruning, deleted files leave "orphan" resources running indefinitely.
  * **Self-Healing**: If a user manually alters a live cluster resource, ArgoCD detects this configuration drift and automatically overwrites it with the state declared in Git.

### 3. What is the App-of-Apps pattern in ArgoCD, and why is it used?
* **Answer**:
  * The **App-of-Apps** pattern is a design where a single root ArgoCD `Application` points to a directory in Git containing *other* ArgoCD `Application` manifests (declarative definitions of your microservices, monitoring stacks, etc.).
  * **Value**: It allows you to bootstrap and manage your entire cluster setup with a single ArgoCD command. Managing one application automatically provisions, syncs, and updates all child applications recursively.

### 4. What is the difference between a Sync Hook and a Sync Wave in ArgoCD?
* **Answer**:
  * **Sync Wave**: Uses annotations (`argocd.argoproj.io/sync-wave`) to order the deployment of resources sequentially. Lower waves (e.g., `-5`) are created first, while higher waves wait for them to become healthy before starting.
  * **Sync Hook**: Restricts execution to specific lifecycle phases (e.g. `PreSync`, `PostSync`). Typically used to run DB migrations, run test suites, or send slack notifications before/after a deployment.

### 5. How does ArgoCD handle Git server authentication and webhook configuration?
* **Answer**:
  * ArgoCD authenticates with private Git repositories using SSH deploy keys or HTTPS Personal Access Tokens (PATs) stored as cluster Secrets.
  * To eliminate polling latency (which defaults to checking Git every 3 minutes), you configure a webhook on your Git server (GitHub/GitLab) pointing to ArgoCD's `/api/webhook` endpoint. The Git server triggers ArgoCD to sync instantly upon every git push.
