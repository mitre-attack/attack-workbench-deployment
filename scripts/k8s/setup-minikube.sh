#!/usr/bin/env bash
# setup-minikube.sh — Bootstrap minikube and deploy ATT&CK Workbench locally.
#
# Usage:
#   ./setup-minikube.sh [--with-taxii]
#
# Prerequisites: minikube, kubectl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_DIR="$REPO_DIR/k8s"
WITH_TAXII=false

for arg in "$@"; do
  case "$arg" in
    --with-taxii) WITH_TAXII=true ;;
    -h|--help)
      echo "Usage: $0 [--with-taxii]"
      echo ""
      echo "Options:"
      echo "  --with-taxii    Include the TAXII 2.1 server component"
      echo "  -h, --help      Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

echo "=== ATT&CK Workbench: minikube Setup ==="
echo ""

# 1. Start minikube (if not running)
if minikube status 2>/dev/null | grep -q "Running"; then
  echo "[OK] minikube is already running."
else
  echo "[..] Starting minikube..."
  minikube start --cpus=4 --memory=8192 --driver=docker
  echo "[OK] minikube started."
fi

# 2. Enable NGINX Ingress addon
echo "[..] Enabling NGINX Ingress addon..."
minikube addons enable ingress
echo "[OK] Ingress enabled."

# 3. Enable TAXII if requested
if [ "$WITH_TAXII" = true ]; then
  echo "[..] Enabling TAXII component in local overlay..."
  KUSTOMIZATION_FILE="$K8S_DIR/overlays/local/kustomization.yaml"
  # Uncomment the components lines
  sed -i.bak 's/^# components:/components:/' "$KUSTOMIZATION_FILE"
  sed -i.bak 's/^# - \.\.\/\.\.\/components\/taxii/- ..\/..\/components\/taxii/' "$KUSTOMIZATION_FILE"
  rm -f "${KUSTOMIZATION_FILE}.bak"
  echo "[OK] TAXII component enabled."
fi

# 4. Apply the local overlay
echo "[..] Deploying ATT&CK Workbench..."
kubectl apply -k "$K8S_DIR/overlays/local"

# 5. Wait for rollout
echo "[..] Waiting for deployments to become ready..."
kubectl rollout status deployment/frontend -n attack-workbench --timeout=180s
kubectl rollout status deployment/rest-api -n attack-workbench --timeout=180s
kubectl rollout status statefulset/mongodb -n attack-workbench --timeout=180s

if [ "$WITH_TAXII" = true ]; then
  kubectl rollout status deployment/taxii -n attack-workbench --timeout=180s
  kubectl rollout status deployment/memcached -n attack-workbench --timeout=120s
fi

# 6. Print access info
MINIKUBE_IP=$(minikube ip)
echo ""
echo "================================================"
echo "  ATT&CK Workbench is ready!"
echo "================================================"
echo ""
echo "Add this line to /etc/hosts:"
echo "  $MINIKUBE_IP workbench.local"
echo ""
echo "Then visit: http://workbench.local"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n attack-workbench"
echo "  kubectl logs -f deployment/rest-api -n attack-workbench"
echo "  minikube dashboard"
echo ""
