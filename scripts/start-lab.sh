#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

K3D_CLUSTER="${K3D_CLUSTER:-qa-lab}"
NODE_PORT="${NODE_PORT:-30080}"
DASHBOARD_PORT="${DASHBOARD_PORT:-8443}"

log() {
  echo "[start-lab] $*"
}

check_port() {
  local port="$1"
  lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
}

wait_for_url() {
  local url="$1"
  local label="$2"
  local timeout="${3:-60}"
  local elapsed=0

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    if curl -sf "${url}" >/dev/null 2>&1 || curl -skf "${url}" >/dev/null 2>&1; then
      log "${label} is reachable at ${url}"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  log "WARNING: ${label} not reachable yet at ${url}"
  return 1
}

log "Step 1: Ensuring k3d cluster and manifests..."
bash "${SCRIPT_DIR}/setup-k3d-cluster.sh"

if k3d cluster list 2>/dev/null | grep -q "${K3D_CLUSTER}"; then
  if ! check_port "${NODE_PORT}"; then
    log "Adding NodePort mapping ${NODE_PORT} to k3d cluster..."
    k3d cluster edit "${K3D_CLUSTER}" --port-add "${NODE_PORT}:${NODE_PORT}@server:0" || true
  fi
fi

log "Step 2: Installing Kubernetes Dashboard (if needed)..."
if ! kubectl get namespace kubernetes-dashboard >/dev/null 2>&1; then
  kubectl apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
fi

if ! kubectl get serviceaccount dashboard-admin -n kubernetes-dashboard >/dev/null 2>&1; then
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: dashboard-admin
    namespace: kubernetes-dashboard
EOF
fi

kubectl rollout status deployment/kubernetes-dashboard -n kubernetes-dashboard --timeout=120s 2>/dev/null || true

if ! pgrep -f "kubectl port-forward.*kubernetes-dashboard.*${DASHBOARD_PORT}:443" >/dev/null 2>&1; then
  log "Starting dashboard port-forward on https://localhost:${DASHBOARD_PORT}..."
  nohup kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard "${DASHBOARD_PORT}:443" \
    >/tmp/k8s-dashboard-port-forward.log 2>&1 &
  sleep 3
fi

log ""
log "=== Lab Status ==="
kubectl get pods,svc -n qa-lab 2>/dev/null || true

DASHBOARD_TOKEN="$(kubectl -n kubernetes-dashboard create token dashboard-admin 2>/dev/null || true)"

log ""
log "URLs:"
log "  Loan Service:  http://localhost:${NODE_PORT}/api/loans"
log "  Health:        http://localhost:${NODE_PORT}/actuator/health"
log "  K8s Dashboard: https://localhost:${DASHBOARD_PORT}"

if [[ -n "${DASHBOARD_TOKEN}" ]]; then
  log ""
  log "Dashboard token: ${DASHBOARD_TOKEN}"
fi

log ""
wait_for_url "http://localhost:${NODE_PORT}/actuator/health" "Loan Service" 30 || true
wait_for_url "https://localhost:${DASHBOARD_PORT}" "K8s Dashboard" 30 || true

log ""
log "Lab startup complete."
log "Deploy the app with: ./scripts/deploy-and-test.sh"
