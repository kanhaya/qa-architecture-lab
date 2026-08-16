#!/usr/bin/env bash
set -euo pipefail

K3D_CLUSTER="${K3D_CLUSTER:-qa-lab}"
REGISTRY_NAME="${REGISTRY_NAME:-qa-registry}"
REGISTRY_HOST_PORT="${REGISTRY_HOST_PORT:-5001}"
NODE_PORT="${NODE_PORT:-30080}"
AGENTS="${AGENTS:-2}"

log() {
  echo "[setup-k3d-cluster] $*"
}

if ! command -v k3d >/dev/null 2>&1; then
  echo "[setup-k3d-cluster] ERROR: k3d is not installed. Install from https://k3d.io/" >&2
  exit 1
fi

if k3d cluster list 2>/dev/null | grep -q "${K3D_CLUSTER}"; then
  log "Cluster '${K3D_CLUSTER}' already exists. Skipping creation."
  if ! lsof -nP -iTCP:"${NODE_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    log "Adding NodePort mapping ${NODE_PORT} to existing cluster..."
    k3d cluster edit "${K3D_CLUSTER}" --port-add "${NODE_PORT}:${NODE_PORT}@server:0" || true
  fi
  log "To recreate: k3d cluster delete ${K3D_CLUSTER} && re-run this script"
else
  log "Creating k3d cluster '${K3D_CLUSTER}' with registry and NodePort mapping..."
  k3d cluster create "${K3D_CLUSTER}" \
    --registry-create "${REGISTRY_NAME}:0.0.0.0:${REGISTRY_HOST_PORT}" \
    --port "${NODE_PORT}:${NODE_PORT}@server:0" \
    --agents "${AGENTS}"
fi

log "Applying Kubernetes manifests..."
kubectl apply -f "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/k8s/"

log ""
log "Cluster ready."
log "  Registry (host push):  localhost:${REGISTRY_HOST_PORT}"
log "  Registry (in-cluster): k3d-${REGISTRY_NAME}:5000"
log "  Service URL:           http://localhost:${NODE_PORT}"
log "  Namespace:             qa-lab"
log ""
log "Push an image:"
log "  docker build -t localhost:${REGISTRY_HOST_PORT}/loan-service:1.0 ."
log "  docker push localhost:${REGISTRY_HOST_PORT}/loan-service:1.0"
