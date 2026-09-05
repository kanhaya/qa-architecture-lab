#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-qa-lab}"
DEPLOYMENT="${DEPLOYMENT:-loan-service}"
SERVICE="${SERVICE:-loan-service}"
BASE_URL="${BASE_URL:-http://localhost:30080}"
TIMEOUT="${TIMEOUT:-120}"
DESIRED_REPLICAS="${DESIRED_REPLICAS:-1}"

log() {
  echo "[validate-deployment] $*"
}

fail() {
  echo "[validate-deployment] ERROR: $*" >&2
  exit 1
}

log "Checking deployment '${DEPLOYMENT}' in namespace '${NAMESPACE}'..."
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  fail "Deployment '${DEPLOYMENT}' not found in namespace '${NAMESPACE}'"
fi

ready_replicas=$(kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}')
desired_replicas=$(kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')

if [[ -z "${ready_replicas}" || "${ready_replicas}" != "${desired_replicas}" ]]; then
  fail "Deployment not ready: readyReplicas=${ready_replicas:-0}, desiredReplicas=${desired_replicas}"
fi

if [[ "${desired_replicas}" != "${DESIRED_REPLICAS}" ]]; then
  log "Warning: desired replicas is ${desired_replicas}, expected ${DESIRED_REPLICAS}"
fi

log "Checking pods..."
not_running=$(kubectl get pods -n "${NAMESPACE}" -l "app=${DEPLOYMENT}" \
  --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "${not_running}" != "0" ]]; then
  kubectl get pods -n "${NAMESPACE}" -l "app=${DEPLOYMENT}"
  fail "${not_running} pod(s) are not in Running state"
fi

not_ready=$(kubectl get pods -n "${NAMESPACE}" -l "app=${DEPLOYMENT}" \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
  | awk '$2 != "True" {count++} END {print count+0}')
if [[ "${not_ready}" != "0" ]]; then
  kubectl get pods -n "${NAMESPACE}" -l "app=${DEPLOYMENT}"
  fail "${not_ready} pod(s) are not Ready"
fi

log "Checking service '${SERVICE}'..."
if ! kubectl get service "${SERVICE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  fail "Service '${SERVICE}' not found in namespace '${NAMESPACE}'"
fi

log "Polling health endpoint at ${BASE_URL}/actuator/health (timeout: ${TIMEOUT}s)..."
elapsed=0
interval=5
while [[ "${elapsed}" -lt "${TIMEOUT}" ]]; do
  if curl -sf "${BASE_URL}/actuator/health" | grep -q '"status":"UP"'; then
    log "Health check passed"
    log "Deployment validation successful"
    exit 0
  fi
  sleep "${interval}"
  elapsed=$((elapsed + interval))
  log "Waiting for health endpoint... (${elapsed}s/${TIMEOUT}s)"
done

fail "Health endpoint did not return UP within ${TIMEOUT} seconds"
