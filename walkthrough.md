# Master Walkthrough & Timeline Diary: GitOps Galaxy

This document records the exact step-by-step execution timeline, commands, wait times, and troubleshooting resolution during our Helm and ArgoCD GitOps deployment.

---

## 🏗️ Step 1: Quotas and Space Provisioning
* **What we did**: Configured resource constraints on our application namespace to restrict CPU/Memory allocations.
* **Commands run**:
  ```bash
  kubectl apply -f manifests/namespace-limits.yaml
  ```
* **Wait times**: Immediate apply (**~1 second**).
* **Verification**: `kubectl get resourcequotas -n vitals-app` (shows active hard limits).

---

## 💾 Step 2: Deploying PostgreSQL via Helm
* **What we did**: Added the Bitnami repository, synced it, and installed PostgreSQL with persistent disk allocation and memory limits capped to conserve Mac RAM.
* **Commands run**:
  ```bash
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo update
  helm install vitals-db bitnami/postgresql -n vitals-app \
    --set primary.persistence.size=1Gi \
    --set primary.resources.requests.memory=128Mi \
    --set primary.resources.limits.memory=256Mi \
    --set primary.resources.requests.cpu=50m \
    --set primary.resources.limits.cpu=100m \
    --set auth.database=vitals \
    --set auth.username=vitals_user \
    --set auth.password=vitals_password \
    --set readReplicas.resources.requests.memory=128Mi \
    --set readReplicas.resources.limits.memory=256Mi
  ```
* **Wait times**: 
  * Docker image pull and pod initialization: **~1.5 minutes**.
* **Verification**:
  * Pod status: `kubectl get po -n vitals-app -l app.kubernetes.io/name=postgresql` (transitions to `1/1 Running`).

---

## 📡 Step 3: Local Cluster Git Server Setup
* **What we did**: Deployed a lightweight Alpine pod running a bare `git daemon` to act as our local version control origin inside the cluster network.
* **Commands run**:
  ```bash
  kubectl apply -f manifests/git-server.yaml
  ```
* **Wait times**: Pod compile and container startup: **~10 seconds**.
* **Post-Boot Config**: Configured HEAD to point to main to match our local branch structure:
  ```bash
  kubectl exec -n vitals-app deployment/git-server -c git-server -- git --git-dir=/git/gitops-galaxy.git symbolic-ref HEAD refs/heads/main
  ```

---

## 🔄 Step 4: Port Forwarding & Git Push
* **What we did**: Exposed git daemon port `9418` to our host machine via background port-forwarding, initialized our git repository locally, and pushed our Helm charts to the cluster.
* **Commands run**:
  ```bash
  # Background port-forward
  kubectl port-forward -n vitals-app service/git-server 9418:9418 &
  
  # Local Git config & Push
  git init
  git checkout -b main
  git config user.email "william@kood.tech"
  git config user.name "William"
  git add .
  git commit -m "Initial commit of GitOps Galaxy configurations"
  git remote add origin git://127.0.0.1:9418/gitops-galaxy.git
  git push -u origin main
  ```
* **Wait times**: Git repository sync: **~2 seconds**.

---

## 🐙 Step 5: Installing ArgoCD via Helm
* **What we did**: Installed ArgoCD using optimized memory bounds, disabling Dex, applicationSet controllers, and notification systems to save ~300MB of RAM.
* **Commands run**:
  ```bash
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  helm install argocd argo/argo-cd --namespace argocd --create-namespace \
    --set controller.resources.requests.memory=128Mi \
    --set controller.resources.limits.memory=256Mi \
    --set server.resources.requests.memory=64Mi \
    --set server.resources.limits.memory=128Mi \
    --set repoServer.resources.requests.memory=64Mi \
    --set repoServer.resources.limits.memory=128Mi \
    --set applicationSet.enabled=false \
    --set notifications.enabled=false \
    --set dex.enabled=false \
    --set redis.resources.requests.memory=32Mi \
    --set redis.resources.limits.memory=64Mi \
    --set global.imageSignatures.enabled=false
  ```
* **Wait times**: Core pods downloading and starting: **~40 seconds**.

---

## 📈 Step 6: Deploying the Application & Reconciling State
* **What we did**: Applied our ArgoCD application watcher.
* **Commands run**:
  ```bash
  kubectl apply -f manifests/argocd-app.yaml
  ```
* **Troubleshooting Log**:
  * **Issue**: The application sync status remained `Unknown` with error `unable to resolve 'HEAD' to a commit SHA`.
  * **Cause**: Git initialized the bare repository inside the pod with default branch `master`, leaving the symbolic link `HEAD` pointing to `refs/heads/master`. Because we pushed `main`, `master` did not exist.
  * **Resolution**: Updated `argocd-app.yaml` `targetRevision` from `HEAD` to `main`, committed/pushed the fix, and ran `kubectl symbolic-ref` inside the server pod.
* **Result**: Re-synchronized successfully. ArgoCD terminated the old 8-day-old pods and rolled out our Helm-managed deployments.
  * **Sync Status**: `Synced`
  * **Health Status**: `Healthy`

---

## 🔬 Step 7: Database Connectivity Validation Job
* **What we did**: Deployed a validation job that logs in to PostgreSQL, creates a table, inserts a value, reads it back, and reports success.
* **Troubleshooting Log**:
  * **Issue**: The job creation request was blocked by the admission controller with error `failed quota: vitals-quota: must specify limits.cpu...`
  * **Cause**: Our newly applied ResourceQuota mandates that ALL containers in the namespace must declare CPU/Memory limits and requests.
  * **Resolution**: Updated `database-job.yaml` to specify requests and limits in the containers block. Deallocated/re-applied the job.
* **Result**: Passed successfully. Pod logs reported:
  `PostgreSQL Connection Successful! Read/Write test passed.`

---

## 🛡️ Step 8: Drift Simulation & Self-Healing Validation
* **What we did**: Scaled our deployment manually via `kubectl` to test self-healing.
* **Commands run**:
  ```bash
  kubectl scale deployment vitals-frontend -n vitals-app --replicas=4
  sleep 5
  kubectl get deployment vitals-frontend -n vitals-app
  ```
* **Result**: Within 5 seconds, ArgoCD detected the state mismatch against Git, marked the cluster `OutOfSync`, and scaled it back down to `2/2` replicas automatically.
