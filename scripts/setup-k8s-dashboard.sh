#!/usr/bin/env bash
set -euo pipefail

DASHBOARD_VERSION="${DASHBOARD_VERSION:-v2.7.0}"
DASHBOARD_NAMESPACE="${DASHBOARD_NAMESPACE:-kubernetes-dashboard}"
LOCAL_PORT="${LOCAL_PORT:-8443}"

log() {
  echo "[setup-k8s-dashboard] $*"
}

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[setup-k8s-dashboard] ERROR: kubectl is not installed." >&2
  exit 1
fi

log "Installing Kubernetes Dashboard ${DASHBOARD_VERSION}..."
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml"

log "Creating dashboard admin service account..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin
  namespace: ${DASHBOARD_NAMESPACE}
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
    namespace: ${DASHBOARD_NAMESPACE}
EOF

log "Waiting for dashboard pod..."
kubectl rollout status deployment/kubernetes-dashboard -n "${DASHBOARD_NAMESPACE}" --timeout=120s

TOKEN="$(kubectl -n "${DASHBOARD_NAMESPACE}" create token dashboard-admin)"

log ""
log "Kubernetes Dashboard is ready."
log "  URL:   https://localhost:${LOCAL_PORT}"
log "  Token: ${TOKEN}"
log ""
log "Starting port-forward (Ctrl+C to stop)..."
log "Open https://localhost:${LOCAL_PORT} and paste the token above."
kubectl port-forward -n "${DASHBOARD_NAMESPACE}" "svc/kubernetes-dashboard" "${LOCAL_PORT}:443"
