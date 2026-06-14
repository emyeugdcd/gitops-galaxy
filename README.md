# GitOps Galaxy: Declarative Continuous Delivery with Helm & ArgoCD

Welcome to GitOps Galaxy, the 6th project of the DevOps study module provided by kood/sisu. This project demonstrates the transition of a microservices application (Go Backend + NodeJS Frontend) from static Kubernetes manifests (`cluster-chronicles`) to a dynamic, automated **GitOps Workflow** using **Helm** for packaging and **ArgoCD** for continuous reconciliation/delivery.

It also configures an in-cluster **PostgreSQL Database** via Helm with persistent storage and resource quotas, verified through an automated Kubernetes Job.

Here's a summary of all previous projects so you have context for what you're reviewing:

**Project 1 - Server Sorcery**: I have built a network of 4 virtual machines simulating real-life infrastructure: a load balancer, two web servers, an app server. 
- Each VM is automatically installed with the necessary software, security hardening (UFW, Fail2Ban, SSH restrictions), and networking configuration using Ansible.

Link to project 1: [https://github.com/emyeugdcd/server-sorcery-101](https://github.com/emyeugdcd/server-sorcery-101)

**Project 2 - Infrastructure Insight**: with the 4 VMs of the first project running, I then built a surgical-theatre-themed system metrics dashboard (well since I am a surgical nurse haha). The backend is a Go application running on the appserver: it reads raw performance data directly from the appserver's Linux kernel's virtual filesystem and exposes that data as a JSON API. The frontend is a Node.js application running on both webservers: it fetches from the backend API and renders the metrics as a live Medical Dashboard in the browser. When you visit http://192.168.56.11/, the loadbalancer routes your request to either webserver1 or webserver2. Backend and Frontend applications are deployed by Docker.

Link to project 2: [https://github.com/emyeugdcd/infrastructure-insight](https://github.com/emyeugdcd/infrastructure-insight)

**Project 3 - Automation Alchemy**: Automates everything from the first two projects into a single command: ./super_deploy.sh. Additionally, a GitHub Actions CI/CD pipeline is configured so that whenever we make changes to the backend and frontend application codes and push them, the corresponding running Docker containers will be destroyed and built again. That is what CI/CD means: continuous integration and continuous delivery

Link to project 3: [https://github.com/emyeugdcd/automation-alchemy](https://github.com/emyeugdcd/automation-alchemy)

**Project 4 - Sherlock Logs**: This project builds upon the `automation-alchemy` infrastructure, integrating a robust observability stack. It adds a centralized **Monitoring VM** that hosts Prometheus, Grafana, and the ELK Stack (Elasticsearch, Logstash, Kibana) to provide real-time metrics and aggregated logging across all nodes.

Link to project 4: [https://github.com/emyeugdcd/sherlock-logs](https://github.com/emyeugdcd/sherlock-logs)


**Project 5 - Cluster Chronicles**: This project continues from the previous four projects and demonstrates the complete migration of a microservices application (Go Backend + NodeJS Frontend) from traditional VM-based environments (`sherlock-logs`) to a local, Kubernetes-orchestrated cluster using **Minikube**. 

Link to project 5: [https://github.com/emyeugdcd/cluster-chronicles](https://github.com/emyeugdcd/cluster-chronicles)

**Project 6 - GitOps Galaxy**: This project continues from the previous five projects and demonstrates the transition of a microservices application (Go Backend + NodeJS Frontend) from static Kubernetes manifests (`cluster-chronicles`) to a dynamic, automated **GitOps Workflow** using **Helm** for packaging and **ArgoCD** for continuous reconciliation/delivery. It also configures an in-cluster **PostgreSQL Database** via Helm with persistent storage and resource quotas, verified through an automated Kubernetes Job.

Link to project 6: [https://github.com/emyeugdcd/gitops-galaxy](https://github.com/emyeugdcd/gitops-galaxy)

---

## 1. Infrastructure Overview

```text
 ┌────────────────┐
 │  Local Machine │  (developer commits changes to Values.yaml)
 └───────┬────────┘
         │ (git push)
         ▼
 ┌────────────────┐
 │    Git Repo    │◀──────────────────────────────────────────┐
 │ (Git Server)   │                                           │
 └───────┬────────┘                                           │
         │                                                    │
         │ (Watches Git for new commits)                      │
         ▼                                                    │
 ┌────────────────┐                                           │
 │    ArgoCD      │ (Detects out-of-sync / drift)             │
 └───────┬────────┘                                           │
         │                                                    │
         │ (Automatically applies / reconciles state)         │
         ▼                                                    │
 ┌────────────────────────────────────────────────────────┐   │
 │                   Kubernetes Cluster                   │   │
 │                                                        │   │
 │  [ vitals-app Namespace ]                              │   │
 │   ├── PostgreSQL (Helm install vitals-db)              │   │
 │   ├── Backend Pod (vitals-backend)                     │   │
 │   └── Frontend Pods (vitals-frontend) ───[ Manually ]──┼───┘
 │                                          [ scaled?  ]  |
 └────────────────────────────────────────────────────────┘
```

To run this project fully offline locally without external repository credentials, I have deployed a lightweight, bare-metal **Git Server Daemon** (`git-server`) inside the cluster. It serves as the remote repository host.

---

## 2. Cluster Setup & Installation

There are two ways to run the setup of this project. You can either run the command to get everything up and running
```bash
./deploy.sh
```

Or if you are interested in learning how things work under the hood, feel free to follow the steps below:

### Step 1: Start Minikube & Enable Addons
```bash
minikube start --driver=docker --cpus=4 --memory=6144
minikube addons enable ingress
minikube addons enable metrics-server
```

### Step 2: Set Namespace Resource Quotas
Apply namespace limits to prevent CPU/Memory exhaustion:
```bash
kubectl apply -f manifests/namespace-limits.yaml
```

### Step 3: Deploy PostgreSQL Database via Helm
Add the Bitnami repository and install PostgreSQL with strict memory caps and persistence enabled:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install vitals-db bitnami/postgresql -n vitals-app --create-namespace \
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

### Step 4: Deploy the In-Cluster Git Server
Apply the git server service and deployment configurations:
```bash
kubectl apply -f manifests/git-server.yaml
```
Once the pod is running, configure its HEAD symbolic reference:
```bash
kubectl exec -n vitals-app deployment/git-server -c git-server -- git --git-dir=/git/gitops-galaxy.git symbolic-ref HEAD refs/heads/main
```

### Step 5: Push your Code to the Cluster Git Server
1. Start port-forwarding on port 9418 to expose the Git server to your local machine:
   ```bash
   kubectl port-forward -n vitals-app service/git-server 9418:9418 &
   ```
2. Initialize Git, add the remote, and push:
   ```bash
   git init
   git checkout -b main
   git config user.email "william@kood.tech"
   git config user.name "William"
   git add .
   git commit -m "Initial commit of Helm charts and manifests"
   git remote add origin git://127.0.0.1:9418/gitops-galaxy.git
   git push -u origin main
   ```

### Step 6: Deploy ArgoCD via Helm
Install a resource-optimized, non-HA installation of ArgoCD:
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

### Step 7: Apply the ArgoCD Application Manifest
Deploy the CD Application watcher to sync the Helm chart from the git server:
```bash
kubectl apply -f manifests/argocd-app.yaml
```

---

## 3. Validation & Testing Runbook

### Test 1: Verify PostgreSQL Connectivity (Batch Job)
Apply the batch Job which writes and reads from PostgreSQL:
```bash
kubectl apply -f manifests/database-job.yaml
```
Verify the job status and logs:
```bash
kubectl get jobs -n vitals-app
# Expected: COMPLETIONS 1/1

kubectl logs -n vitals-app -l job-name=postgres-connection-check
# Expected: "PostgreSQL Connection Successful! Read/Write test passed."
```

### Test 2: Access the ArgoCD Dashboard UI
1. Retrieve the autogenerated ArgoCD admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
   ```
2. Port-forward the ArgoCD UI:
   ```bash
   kubectl port-forward service/argocd-server -n argocd 8080:443
   ```
3. Open `https://localhost:8080` in your browser, log in as `admin`, and review the `vitals-app` tree.

### Test 3: Demonstrate Configuration Drift & Self-Healing (SRE Interview Scenario)
Manually scale the frontend deployment replicas via `kubectl`:
```bash
kubectl scale deployment vitals-frontend -n vitals-app --replicas=4
```
Within seconds, execute:
```bash
kubectl get deployment vitals-frontend -n vitals-app
```
**Expected Outcome**: ArgoCD detects the discrepancy against Git (which declares 2 replicas). It flags the state as `OutOfSync` and instantly reconciles the cluster, scaling it back down to `2/2` replicas automatically.

---

## 4. Study Guide & Core Concepts

To prepare for the review, in the /docs directory, I have prepared a study-guide.md file that serves as a comprehensive guide for understanding the core concepts of Helm and GitOps. This study-guide.md can be used together with the how-to-test.md to learn more about the concepts and technology used in this project. 

Key areas covered in the study-guide.md:
- **Helm Mechanics**: Packaging structures, Go templates syntax, dependency management, dry-run template compilation, and lifecycle hooks.
- **Declarative GitOps**: Principles of pulling continuous delivery, push vs. pull architecture, credentials isolation, self-healing options (Prune, Self-Heal), and ArgoCD Image Updater automation. I also added an overview of how to manage multiple git remotes to jog your memory on the subject.
- **Architectural Comparison**: Detailed comparison mapping differences between the imperative setup of [Cluster Chronicles] and the declarative GitOps engine of [GitOps Galaxy].
---

## 5. Complete Testing Rubric

To make the review process easier, I have fully documented answers, commands, and verification guidelines for all 40 requirements in [how-to-test.md]. 
