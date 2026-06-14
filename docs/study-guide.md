# GitOps Galaxy: Helm & ArgoCD Study Guide 🌌

This study guide serves as teaching material and an architectural review of the transition from the static Kubernetes deployments of **Cluster Chronicles** to the declarative, package-managed, and automated GitOps continuous delivery pipeline of **GitOps Galaxy**.

---

## Project Architecture Overview

The diagram below details the end-to-end pull-based continuous delivery flow implemented in **GitOps Galaxy**:

```mermaid
graph TD
    subgraph Local Machine
        dev[Developer] -- "Modifies values.yaml / Code" --> git_push[git push]
    end

    subgraph Cluster Git Server
        git_repo["In-Cluster Git Daemon<br>(gitops-galaxy.git)"]
    end

    subgraph ArgoCD Control Plane (argocd namespace)
        argo_controller["ArgoCD Application Controller"]
        argo_repo_server["ArgoCD Repo Server"]
        argo_ui["ArgoCD UI / Dashboard"]
    end

    subgraph Target Workloads (vitals-app namespace)
        pg_db[(PostgreSQL DB<br>Helm: vitals-db)]
        backend_pod[Backend API Pods]
        frontend_pod[Frontend Web Pods]
    end

    git_push -- "TCP Port 9418" --> git_repo
    argo_repo_server -- "Polls every 3m / webhook" --> git_repo
    argo_controller -- "Compares Git against live state" --> argo_repo_server
    argo_controller -- "1. Auto-Reconciles / App-Sync" --> target_namespaces["Kubernetes API Server"]
    target_namespaces -- "Applies manifest templates" --> backend_pod
    target_namespaces -- "Applies manifest templates" --> frontend_pod
    target_namespaces -- "Manages PostgreSQL" --> pg_db

    classDef k8s fill:#326ce5,stroke:#fff,stroke-width:2px,color:#fff;
    classDef gitops fill:#f47023,stroke:#fff,stroke-width:2px,color:#fff;
    class pg_db,backend_pod,frontend_pod k8s;
    class argo_controller,argo_repo_server,argo_ui gitops;
```

---

## Part 1: Helm Chart Mechanics & Templating

### 1. The Core Concepts of Helm
Helm is the package manager for Kubernetes. Just as `apt` is for Ubuntu or `npm` is for Node.js, Helm simplifies how we install, configure, upgrade, and delete applications inside a Kubernetes cluster. 

Instead of managing duplicate, hardcoded YAML files for every environment, Helm packages them into a **Chart** with a centralized configuration file called `values.yaml`.

### 2. Helm Chart Structure
A typical Helm chart follows this standard layout:
```text
vitals-app/
├── Chart.yaml          # Metadata (name, version, apiVersion, dependencies)
├── values.yaml         # Default configuration variables (overrideable)
├── templates/          # Kubernetes manifest templates with template expressions
│   ├── _helpers.tpl    # Named helper templates (macros)
│   ├── deployment.yaml # App deployment template
│   └── service.yaml    # Service template
└── charts/             # Sub-charts (dependencies)
```

### 3. Templating Syntax and Go Templates
Helm uses the Go template language. During a deployment, Helm compiles the template files under `templates/` by interpolating values from `values.yaml` and built-in variables.

*   **Variables**: Access values using dot notation. For example, `{{ .Values.backend.replicaCount }}` retrieves the backend replica count.
*   **Built-in Objects**:
    *   `.Release.Name`: The name of the Helm release instance (e.g., `vitals-release`).
    *   `.Chart.Name`: The chart name (e.g., `vitals-app`).
    *   `.Capabilities`: Cluster capability details.
*   **Whitespace Control**: Placed hyphens (e.g., `{{-` and `-}}`) strip leading or trailing spaces and newlines. This is crucial for keeping Kubernetes YAML indentation valid.
*   **Pipelines and Functions**: Filters can format data.
    *   `quote`: `{{ .Values.namespace | quote }}` outputs `"vitals-app"`.
    *   `b64enc`: `{{ .Values.secretData | b64enc }}` base64-encodes values inside secret templates.
*   **Conditionals**:
    ```yaml
    {{- if .Values.ingress.enabled }}
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    ...
    {{- end }}
    ```

### 4. Dependency Management
If your application depends on a database (like PostgreSQL), you can declare it under the `dependencies` block in `Chart.yaml` instead of deploying it manually.
*   **Chart.yaml declaration**:
    ```yaml
    dependencies:
      - name: postgresql
        version: "15.x.x"
        repository: "https://charts.bitnami.com/bitnami"
    ```
*   **Update Command**: Run `helm dependency update` to pull the dependency charts into the local `/charts` directory.

### 5. Lifecycle Hooks
Helm hooks allow developers to run actions at specific moments during a chart's installation or upgrade.
*   `pre-install`: Runs database schema migrations before deploying the app.
*   `post-install`: Triggers notifications or setups configuration tasks.
*   `test`: Executes verification jobs after the installation (triggered via `helm test`).

---

## Part 2: Declarative GitOps with ArgoCD

### 1. GitOps Core Principles
GitOps is a continuous delivery pattern that uses **Git as the single source of truth** for infrastructure and application states.
1.  **Declarative Description**: All target resources (deployments, namespaces, networks) are described in Git manifests.
2.  **Versioned & Immutable**: The desired cluster state is versioned in Git (providing auditing and instant reverts).
3.  **Automated Pull Loop**: An in-cluster controller pulls modifications automatically, rather than external scripts pushing changes.
4.  **Continuous Reconciliation**: The controller corrects drift dynamically when the live cluster differs from Git.

### 2. Push vs. Pull Architecture
Comparing traditional CI/CD direct push deployments (e.g., Jenkins) vs. GitOps pull models (e.g., ArgoCD):

| Architectural Dimension | Push Model (e.g., Jenkins Direct) | Pull Model (e.g., ArgoCD GitOps) |
| :--- | :--- | :--- |
| **Pipeline Access** | Jenkins needs cluster administrator credentials (`kubeconfig`) to apply files. | No cluster credentials leave the cluster. The CI only pushes to Git. |
| **Network Security** | Requires exposing cluster API port (`6443`) to the external build agents. | Cluster remains closed. ArgoCD pulls data via outbound connections to Git. |
| **Configuration Drift** | If a resource is altered manually, the change remains until the next build. | ArgoCD immediately flags drift and reverts it back to Git state. |
| **Rollbacks** | Requires executing a pipeline rebuild or executing manual commands. | A standard `git revert` instantly triggers a rollback in the cluster. |

### 3. Sync Policies & Safety Options
ArgoCD uses the **Application Custom Resource Definition (CRD)** to monitor states. Key configurations include:
*   **Automated Sync**: ArgoCD automatically deploys changes when commits are pushed.
*   **Prune**: Deletes resources in the cluster if their manifest files are deleted from the Git repository.
*   **Self-Heal**: Automatically overwrites manual cluster overrides in real-time.
*   **ApplyOutOfSyncOnly**: Patches only the shifted resources, optimizing API traffic.

### 4. ArgoCD Image Updater
ArgoCD Image Updater is an extension that automates image updates. 
*   It monitors a container registry for new tags.
*   When a new tag matching semantic version guidelines (e.g., `semver` patch updates) is pushed, it writes the new image tag directly back to Git (using the Git Write-Back method).
*   ArgoCD detects this new Git commit and syncs the updated image tag into the cluster automatically.

### 5. Where Does the Code Go Right Now?
Right now, when I run git push origin main, my code stays completely local. It goes through port-forwarding and is stored directly on the virtual disk of the git-server Pod running inside my local Minikube cluster node. It does not go to the internet or any Git website. If I delete my Minikube cluster, that specific remote repository is gone (though my local files on my Mac's hard drive remain perfectly safe).

#### How Git Remotes Work (The Secret to Multiple Hosts)
In Git, a Remote is simply a nickname (alias) for a URL where Git can push and pull code. By convention, the default remote is named origin, but you can have as many remotes with whatever names you want! Shall we have a quick reminder on how to manage git remotes? 

Let's demonstrate how I can push my code to multiple Git repositories at once, e.g. cluster, gitea and github, both local and remote. 
Right now, my nicknames look like this:
```
origin ➔ git://127.0.0.1:9418/gitops-galaxy.git (Local Cluster Pod)
```

If I want to push my code to Gitea and GitHub as well, I can add new nicknames

#### Step-by-Step: Renaming and Adding Gitea & GitHub
Step 1: Check the current remotes
Run this command in the gitops-galaxy terminal:
```
bash    
git remote -v
```

The output will show `origin` pointing to the local IP address on port 9418.

Step 2: Rename origin so it is not confusing
Instead of calling the cluster git server origin, let's rename it to cluster:
```
bash
git remote rename origin cluster
```

Now, `git push cluster main` will push to the local cluster git server.

Step 3: Add the Gitea and GitHub remotes
First, create empty repositories on the Gitea and GitHub accounts online. Then, run these commands to assign them nicknames:
```
bash
# Add Gitea as 'origin' (since I want it to be my main repository, for the school)
git remote add origin https://your-gitea-domain.com/username/gitops-galaxy.git
# Add GitHub as 'github'
git remote add github https://github.com/your-username/gitops-galaxy.git
```

Step 4: Verify my new configuration
Run git remote -v again. It will now show:
```
text
cluster git://127.0.0.1:9418/gitops-galaxy.git (fetch)
cluster git://127.0.0.1:9418/gitops-galaxy.git (push)
origin  https://your-gitea-domain.com/username/gitops-galaxy.git (fetch)
origin  https://your-gitea-domain.com/username/gitops-galaxy.git (push)
github  https://github.com/your-username/gitops-galaxy.git (fetch)
github  https://github.com/your-username/gitops-galaxy.git (push)
```

Step 5: Push my code to the web!
Now I can push to any of them whenever I want:

bash
# Push to Gitea (origin)
git push -u origin main
# Push to GitHub
git push -u github main
# Push to your local cluster git server (needed for offline ArgoCD sync)
git push cluster main

#### How to Tell ArgoCD to Pull from Gitea/GitHub
So now, what if I want ArgoCD to pull my templates from Gitea or GitHub instead of the local cluster pod? Simply open the file `argocd-app.yaml` and modify the repoURL:

```yaml
spec:
  source:
    # Change this from the local cluster URL to your Gitea or GitHub public repo URL:
    repoURL: 'https://github.com/your-username/gitops-galaxy.git'
    targetRevision: main
    path: charts/vitals-app
```

Then apply the change to the cluster:

```bash
kubectl apply -f manifests/argocd-app.yaml
```

(Note: If my repository on Gitea/GitHub is private, I would need to configure repository credentials in the ArgoCD settings so it has permission to clone the code, but if the repository is public, it works instantly without any password setup!)
---

## Part 3: GitOps Galaxy vs. Cluster Chronicles

The following table summarizes the transition from static, manually managed Kubernetes files to dynamic GitOps:

| Feature | Cluster Chronicles (Project 5) | GitOps Galaxy (Project 6) |
| :--- | :--- | :--- |
| **Configuration Management** | Static, duplicate YAML files under `manifests/`. | A single dynamic **Helm Chart** (`charts/vitals-app`) managed by a `values.yaml` file. |
| **Database Deployment** | Custom database YAML manifests with manual management. | Deployed instantly using the industry-standard **Bitnami PostgreSQL Helm Chart**. |
| **Deployment Method** | Imperative: Developer executes `kubectl apply -f manifests/` locally. | Declarative: Developer pushes changes to Git; **ArgoCD** pulls and applies them. |
| **Drift Prevention** | None. Manual resource modifications remain unnoticed. | Strict **Self-Healing** and automatic drift reconciliation. |
| **Image Tagging** | Hardcoded tags or manually edited tags. | Automated **ArgoCD Image Updater** tracking patch versions. |
| **Resource Safety** | Open namespaces with no resource limits. | Strict **Resource Quotas** enforced at the namespace level. |

---

## Part 4: How GitOps Elevates the Project

1.  **Eliminates Human Configuration Error**: There are no manual steps (`kubectl apply`) required to apply resources, which eliminates command typo issues.
2.  **Audit Logs & History**: Every cluster adjustment is linked to a Git commit, showing exactly *who* did *what* and *when*.
3.  **Self-Healing Resilience**: If an operator makes a mistake or a script edits a Service, ArgoCD instantly restores the system to the declared Git state.
4.  **Disaster Recovery**: If the cluster crashes, we can spin up a new Minikube instance and apply `argocd-app.yaml`. ArgoCD will deploy the entire environment (frontend, backend, database) in seconds.
5.  **Secure CI/CD Boundary**: Developers do not need direct access to production cluster access keys, keeping credentials secure.
