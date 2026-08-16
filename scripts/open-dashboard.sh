#!/usr/bin/env bash
set -euo pipefail

DASHBOARD_NAMESPACE="${DASHBOARD_NAMESPACE:-kubernetes-dashboard}"
LOCAL_PORT="${LOCAL_PORT:-8443}"
PID_FILE="/tmp/k8s-dashboard-port-forward.pid"

log() {
  echo "[open-dashboard] $*"
}

if pgrep -f "kubectl port-forward.*kubernetes-dashboard.*${LOCAL_PORT}:443" >/dev/null 2>&1; then
  log "Port-forward already running on https://localhost:${LOCAL_PORT}"
else
  log "Starting port-forward in background..."
  nohup kubectl port-forward -n "${DASHBOARD_NAMESPACE}" svc/kubernetes-dashboard "${LOCAL_PORT}:443" \
    >/tmp/k8s-dashboard-port-forward.log 2>&1 &
  echo $! > "${PID_FILE}"
  sleep 2
fi

TOKEN="$(kubectl -n "${DASHBOARD_NAMESPACE}" create token dashboard-admin 2>/dev/null || true)"

log ""
log "Kubernetes Dashboard"
log "  URL:   https://localhost:${LOCAL_PORT}"
if [[ -n "${TOKEN}" ]]; then
  log "  Token: ${TOKEN}"
else
  log "  Run ./scripts/setup-k8s-dashboard.sh first to create dashboard-admin."
fi
log ""
log "In the dashboard, navigate to namespace: qa-lab"
