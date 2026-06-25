#!/usr/bin/env bash
# deploy.sh — Deploy an ATT&CK Workbench overlay to the current Kubernetes context.
#
# Usage:
#   ./deploy.sh <overlay> [--dry-run]
#
# Examples:
#   ./deploy.sh local
#   ./deploy.sh dev
#   ./deploy.sh prod --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/../../k8s" && pwd)"
DRY_RUN=false

usage() {
  echo "Usage: $0 <overlay> [--dry-run]"
  echo ""
  echo "Overlays: local, dev, prod, pre-prod"
  echo ""
  echo "Options:"
  echo "  --dry-run    Render manifests without applying"
  echo "  -h, --help   Show this help message"
  exit 0
}

if [ $# -lt 1 ]; then
  usage
fi

OVERLAY="$1"
shift

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

OVERLAY_DIR="$K8S_DIR/overlays/$OVERLAY"

if [ ! -d "$OVERLAY_DIR" ]; then
  echo "Error: Overlay '$OVERLAY' not found at $OVERLAY_DIR"
  echo "Available overlays:"
  ls -1 "$K8S_DIR/overlays/"
  exit 1
fi

echo "=== ATT&CK Workbench: Deploy ($OVERLAY) ==="
echo "Context: $(kubectl config current-context)"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "--- Dry run: rendering manifests ---"
  kubectl apply -k "$OVERLAY_DIR" --dry-run=client
  echo ""
  echo "Dry run complete. No changes applied."
  exit 0
fi

echo "[..] Applying overlay: $OVERLAY"
kubectl apply -k "$OVERLAY_DIR"

echo "[..] Waiting for deployments..."
kubectl rollout status deployment/frontend -n attack-workbench --timeout=180s
kubectl rollout status deployment/rest-api -n attack-workbench --timeout=180s
kubectl rollout status statefulset/mongodb -n attack-workbench --timeout=180s

echo ""
echo "[OK] Deployment complete."
kubectl get pods -n attack-workbench
