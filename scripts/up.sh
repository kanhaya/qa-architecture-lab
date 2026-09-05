#!/usr/bin/env bash
set -euo pipefail

# Bring up the full lab: Docker, k3d (Jenkins-compatible names), Jenkins, SonarQube, networks.
#
# Usage:
#   ./scripts/up.sh
#
# Optional:
#   SKIP_JENKINS=1     skip Jenkins container
#   SKIP_DASHBOARD=1   skip Kubernetes Dashboard
#   SKIP_SONAR=1       skip SonarQube
#   JENKINS_CONTAINER  default: jenkins

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Match Jenkinsfile (k3d-qa-cluster, k3d-qa-registry:5000)
export K3D_CLUSTER="${K3D_CLUSTER:-qa-cluster}"
export REGISTRY_NAME="${REGISTRY_NAME:-qa-registry}"
export REGISTRY_HOST_PORT="${REGISTRY_HOST_PORT:-5001}"
export NODE_PORT="${NODE_PORT:-30080}"
export JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"
JENKINS_IMAGE="${JENKINS_IMAGE:-jenkins/jenkins:lts}"
SKIP_JENKINS="${SKIP_JENKINS:-0}"
SKIP_DASHBOARD="${SKIP_DASHBOARD:-0}"
SKIP_SONAR="${SKIP_SONAR:-0}"

log() {
  echo "[up] $*"
}

wait_for_docker() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    log "Starting Docker Desktop..."
    open -a Docker 2>/dev/null || true
  fi
  local elapsed=0
  local timeout=180
  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    if docker info >/dev/null 2>&1; then
      log "Docker is ready."
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  log "ERROR: Docker daemon is not running. Start Docker Desktop and re-run."
  exit 1
}

wait_for_url() {
  local url="$1"
  local label="$2"
  local timeout="${3:-90}"
  local elapsed=0
  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    if curl -sf "${url}" >/dev/null 2>&1 || curl -skf "${url}" >/dev/null 2>&1; then
      log "${label} is up: ${url}"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  log "WARNING: ${label} not reachable yet at ${url}"
  return 1
}

ensure_jenkins() {
  if docker inspect "${JENKINS_CONTAINER}" >/dev/null 2>&1; then
    local running
    running="$(docker inspect -f '{{.State.Running}}' "${JENKINS_CONTAINER}")"
    if [[ "${running}" == "true" ]]; then
      log "Jenkins container '${JENKINS_CONTAINER}' is already running."
      return 0
    fi
    log "Starting existing Jenkins container..."
    if docker start "${JENKINS_CONTAINER}" >/dev/null 2>&1; then
      return 0
    fi
    log "Existing Jenkins container cannot start (stale network). Recreating it; jenkins_home volume is kept."
    docker rm -f "${JENKINS_CONTAINER}" >/dev/null
  fi

  log "Creating Jenkins container '${JENKINS_CONTAINER}'..."
  docker run -d \
    --name "${JENKINS_CONTAINER}" \
    -p 8080:8080 -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "${JENKINS_IMAGE}" >/dev/null
}

fix_jenkins_home_owner() {
  if docker inspect "${JENKINS_CONTAINER}" >/dev/null 2>&1; then
    log "Ensuring jenkins owns /var/jenkins_home (fixes git cache AccessDeniedException)..."
    docker exec -u 0 "${JENKINS_CONTAINER}" chown -R jenkins:jenkins /var/jenkins_home >/dev/null 2>&1 || true
  fi
}

cd "${REPO_ROOT}"

log "=== 1/5 Docker ==="
wait_for_docker

log "=== 2/5 k3d cluster ${K3D_CLUSTER} ==="
bash "${SCRIPT_DIR}/setup-k3d-cluster.sh"

if [[ "${SKIP_DASHBOARD}" != "1" ]]; then
  log "=== Kubernetes Dashboard ==="
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
  bash "${SCRIPT_DIR}/open-dashboard.sh"
fi

if [[ "${SKIP_JENKINS}" != "1" ]]; then
  log "=== 3/5 Jenkins ==="
  ensure_jenkins
  wait_for_url "http://localhost:8080/login" "Jenkins" 120 || true
  fix_jenkins_home_owner
  bash "${SCRIPT_DIR}/setup-jenkins-tools.sh"
  JENKINS_CONTAINER="${JENKINS_CONTAINER}" bash "${SCRIPT_DIR}/setup-jenkins-k3d-network.sh"
else
  log "=== 3/5 Jenkins skipped (SKIP_JENKINS=1) ==="
fi

if [[ "${SKIP_SONAR}" != "1" ]]; then
  log "=== 4/5 SonarQube ==="
  bash "${SCRIPT_DIR}/setup-sonarqube.sh"
else
  log "=== 4/5 SonarQube skipped (SKIP_SONAR=1) ==="
fi

if [[ "${SKIP_JENKINS}" != "1" && "${SKIP_SONAR}" != "1" ]]; then
  log "=== 5/5 Jenkins ↔ Sonar network ==="
  JENKINS_CONTAINER="${JENKINS_CONTAINER}" bash "${SCRIPT_DIR}/setup-jenkins-sonar-network.sh" || true
fi

JENKINS_PASSWORD=""
if [[ "${SKIP_JENKINS}" != "1" ]]; then
  JENKINS_PASSWORD="$(docker exec "${JENKINS_CONTAINER}" cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || true)"
fi

cat <<EOF

============================================================
Lab is up. Build from Jenkins when SONAR_TOKEN is saved.
============================================================

  Jenkins:     http://localhost:8080
  SonarQube:   http://localhost:9000   (admin / QALabAdmin!9000)
  Loan API:    http://localhost:${NODE_PORT}/api/loans
  Health:      http://localhost:${NODE_PORT}/actuator/health
  Dashboard:   https://localhost:8443
  Registry:    localhost:${REGISTRY_HOST_PORT}

EOF

if [[ -n "${JENKINS_PASSWORD}" ]]; then
  echo "  Jenkins initial admin password:"
  echo "    ${JENKINS_PASSWORD}"
  echo ""
fi

cat <<'EOF'
Next:
  1. Copy SONAR_TOKEN from the SonarQube setup output above.
  2. Jenkins → Manage Credentials → Secret text → ID: SONAR_TOKEN
  3. Open job qa-k3d-pipeline (Pipeline from SCM, branch main, Jenkinsfile)
  4. Build Now

  Jenkins needs Maven, Docker CLI, and kubectl inside the agent
  (install on the controller or use a custom agent image).

Local quality gate without Jenkins:
  mvn -pl loan-service -am clean verify

EOF
