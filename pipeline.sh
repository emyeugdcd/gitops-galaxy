#!/usr/bin/env bash
set -e

APP_NAME="vitals-app"
NAMESPACE="vitals-app"
ARGOCD_NAMESPACE="argocd"
TIMEOUT=60
POLL_INTERVAL=3

# Helper to check application health
get_app_health() {
  kubectl get application "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown"
}

get_app_sync() {
  kubectl get application "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown"
}

rollback() {
  echo "⚠️ Alert: Deployment failed or degraded! Initiating automated rollback..."
  
  # Revert the last commit
  git revert --no-edit HEAD
  git push cluster main
  
  echo "🔄 Revert committed. Forcing ArgoCD sync..."
  kubectl patch app "${APP_NAME}" -n "${ARGOCD_NAMESPACE}" --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' || true
  
  echo "⏳ Waiting for rollback deployment to become healthy..."
  for ((i=1; i<=TIMEOUT; i+=POLL_INTERVAL)); do
    health=$(get_app_health)
    sync=$(get_app_sync)
    echo "Current health: $health, sync: $sync"
    if [ "$health" = "Healthy" ] && [ "$sync" = "Synced" ]; then
      echo "✅ Rollback successful! Previous stable version restored."
      exit 0
    fi
    sleep $POLL_INTERVAL
  done
  echo "❌ Rollback timeout exceeded!"
  exit 1
}

# Main command options
case "$1" in
  deploy)
    echo "🚀 Starting CI/CD Deployment simulation..."
    # Update tag to 1.16.0 (valid version)
    sed -i.bak 's/tag: .*/tag: 1.16.0/' charts/vitals-app/values.yaml && rm charts/vitals-app/values.yaml.bak
    
    git add charts/vitals-app/values.yaml
    git commit -m "ci(deploy): update backend tag to 1.16.0" || true
    git push cluster main
    
    echo "⏳ Monitoring deployment health..."
    for ((i=1; i<=TIMEOUT; i+=POLL_INTERVAL)); do
      health=$(get_app_health)
      sync=$(get_app_sync)
      echo "Current health: $health, sync: $sync"
      if [ "$health" = "Healthy" ] && [ "$sync" = "Synced" ]; then
        echo "✅ Deployment successful and verified!"
        exit 0
      fi
      if [ "$health" = "Degraded" ]; then
        rollback
      fi
      sleep $POLL_INTERVAL
    done
    echo "⚠️ Timeout waiting for health. Initiating rollback..."
    rollback
    ;;
    
  test-rollback)
    echo "💥 Starting CI/CD Failure & Rollback simulation..."
    # Update tag to broken value
    sed -i.bak 's/tag: .*/tag: broken-tag-9999/' charts/vitals-app/values.yaml && rm charts/vitals-app/values.yaml.bak
    
    git add charts/vitals-app/values.yaml
    git commit -m "ci(deploy): update backend tag to broken-tag-9999" || true
    git push cluster main
    
    echo "⏳ Monitoring deployment health (expecting failure)..."
    for ((i=1; i<=TIMEOUT; i+=POLL_INTERVAL)); do
      health=$(get_app_health)
      sync=$(get_app_sync)
      echo "Current health: $health, sync: $sync"
      if [ "$health" = "Degraded" ]; then
        rollback
      fi
      # Check if pods go into ImagePullBackOff or ErrImagePull
      if kubectl get pods -n "${NAMESPACE}" 2>/dev/null | grep -q -E "ImagePullBackOff|ErrImagePull"; then
        echo "🚨 Detected container image pull error in cluster namespace!"
        rollback
      fi
      sleep $POLL_INTERVAL
    done
    
    # If still not healthy after timeout, rollback
    echo "⚠️ Timeout waiting for health. Initiating rollback..."
    rollback
    ;;
    
  *)
    echo "Usage: $0 {deploy|test-rollback}"
    exit 1
    ;;
esac
