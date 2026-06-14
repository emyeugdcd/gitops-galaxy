#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting GitOps Galaxy deployment..."

# 1. Start Minikube
echo "Step 1: Starting Minikube cluster and enabling addons..."
minikube start --driver=docker --cpus=4 --memory=6144
minikube addons enable ingress
minikube addons enable metrics-server

# 1.5. Build and Load Docker Images
echo "Step 1.5: Building and loading backend & frontend Docker images..."
docker build -t vitals-backend:latest ./backend
docker build -t vitals-frontend:latest ./frontend
minikube image load vitals-backend:latest
minikube image load vitals-frontend:latest

# 2. Set Namespace Resource Quotas
echo "Step 2: Applying namespace limit ranges..."
kubectl create namespace vitals-app --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f manifests/namespace-limits.yaml

# 3. Deploy PostgreSQL via Helm
echo "Step 3: Installing PostgreSQL via Helm..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade --install vitals-db bitnami/postgresql -n vitals-app --create-namespace \
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

# 4. Deploy the In-Cluster Git Server
echo "Step 4: Deploying Git server daemon..."
kubectl apply -f manifests/git-server.yaml

echo "Waiting for Git server deployment to complete..."
kubectl rollout status deployment/git-server -n vitals-app --timeout=120s

echo "Waiting for git executable to be ready in the git-server container..."
until kubectl exec -n vitals-app deployment/git-server -c git-server -- which git >/dev/null 2>&1; do
  echo "Git is not installed yet inside the container. Waiting 3 seconds..."
  sleep 3
done

echo "Initializing HEAD symbolic reference in git server..."
kubectl exec -n vitals-app deployment/git-server -c git-server -- git --git-dir=/git/gitops-galaxy.git symbolic-ref HEAD refs/heads/main

# 5. Push local configs to the Git Server
echo "Step 5: Setting up local Git repository and pushing changes..."
# Kill any pre-existing port-forwards on port 9418
lsof -ti:9418 | xargs kill -9 2>/dev/null || true

# Start port-forward in the background
echo "Starting background port-forward for Git server on port 9418..."
kubectl port-forward -n vitals-app service/git-server 9418:9418 &
PORT_FORWARD_PID=$!

# Give the port forward a moment to connect
sleep 3

# Initialize repository if not already done
if [ ! -d ".git" ]; then
  git init
  git checkout -b main
fi

# Set remote alias
if ! git remote | grep -q "^cluster$"; then
  git remote add cluster git://127.0.0.1:9418/gitops-galaxy.git
fi

# Configure identity if needed
git config user.email "william@kood.tech" || true
git config user.name "William" || true

# Commit and push
git add .
git commit -m "Initialize GitOps configurations and Helm templates" || true
git push cluster main --force

# 6. Deploy ArgoCD via Helm
echo "Step 6: Installing ArgoCD via Helm..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace \
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

# 6.5. Deploy ArgoCD Image Updater via Helm
echo "Step 6.5: Installing ArgoCD Image Updater via Helm..."
helm upgrade --install argocd-image-updater argo/argocd-image-updater --namespace argocd --create-namespace \
  --set resources.requests.memory=64Mi \
  --set resources.limits.memory=128Mi \
  --set resources.requests.cpu=50m \
  --set resources.limits.cpu=100m

# 7. Apply the ArgoCD Application resource
echo "Step 7: Applying the ArgoCD Application controller manifest..."
kubectl apply -f manifests/argocd-app.yaml

# Output instructions
echo "All workloads applied successfully!"
echo "----------------------------------------------------------------"
echo "To access the ArgoCD Dashboard UI:"
echo "1. Retrieve admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"
echo "2. Run port-forward: kubectl port-forward service/argocd-server -n argocd 8080:443"
echo "3. Open https://localhost:8080 in your browser"
echo "----------------------------------------------------------------"

# Keep the script running to maintain the background port-forward if desired, or exit cleanly.
disown $PORT_FORWARD_PID
echo "Note: The Git server port-forward is running in the background (PID $PORT_FORWARD_PID)."
