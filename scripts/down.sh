#!/usr/bin/env bash
set -euo pipefail

# Stop the QA Architecture Lab and reclaim Docker disk used by this project.
# Does not run `docker system prune -a` (that would delete unrelated images).
#
# Usage:
#   ./scripts/down.sh           # stop stack, delete k3d clusters, Sonar volumes, loan images
#   ./scripts/down.sh --purge   # also remove Sonar/Jenkins/k3s images and jenkins_home
#
# Optional:
#   KEEP_JENKINS=1              leave the Jenkins container running
#   JENKINS_CONTAINER           default: jenkins

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.sonarqube.yml"

PURGE=0
KEEP_JENKINS="${KEEP_JENKINS:-0}"
JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"
K3D_CLUSTERS="${K3D_CLUSTERS:-qa-cluster qa-lab}"

for arg in "$@"; do
  case "${arg}" in
    --purge|-p) PURGE=1 ;;
    --help|-h)
      sed -n '2,14p' "$0"
      exit 0
      ;;
  esac
done

log() {
  echo "[down] $*"
}

df_line() {
  docker system df 2>/dev/null | head -n 20 || true
}

safe_rmi() {
  local ref="$1"
  if [[ -z "${ref}" || "${ref}" == "<none>" ]]; then
    return 0
  fi
  if docker ps -a --filter "ancestor=${ref}" --format '{{.ID}}' | grep -q .; then
    log "Keep image in use: ${ref}"
    return 0
  fi
  if docker image inspect "${ref}" >/dev/null 2>&1; then
    log "Removing image ${ref}"
    docker rmi "${ref}" >/dev/null 2>&1 || docker rmi -f "${ref}" >/dev/null 2>&1 || true
  fi
}

if ! docker info >/dev/null 2>&1; then
  log "Docker is not running; nothing to stop."
  exit 0
fi

log "Disk before cleanup:"
df_line
echo ""

log "Stopping Kubernetes Dashboard port-forward..."
pkill -f "kubectl port-forward.*kubernetes-dashboard" 2>/dev/null || true
rm -f /tmp/k8s-dashboard-port-forward.pid /tmp/k8s-dashboard-port-forward.log

if command -v k3d >/dev/null 2>&1; then
  for cluster in ${K3D_CLUSTERS}; do
    if k3d cluster list 2>/dev/null | grep -qw "${cluster}"; then
      log "Deleting k3d cluster '${cluster}' (nodes + embedded registry)..."
      k3d cluster delete "${cluster}" || true
    else
      log "k3d cluster '${cluster}' not present."
    fi
  done
else
  log "k3d not installed; skip cluster delete."
fi

log "Stopping SonarQube compose stack and volumes..."
if [[ -f "${COMPOSE_FILE}" ]]; then
  docker compose -f "${COMPOSE_FILE}" down -v --remove-orphans --rmi local 2>/dev/null || \
    docker compose -f "${COMPOSE_FILE}" down -v --remove-orphans || true
fi

for cname in sonarqube sonar-db; do
  if docker inspect "${cname}" >/dev/null 2>&1; then
    log "Removing leftover container ${cname}"
    docker rm -f "${cname}" >/dev/null 2>&1 || true
  fi
done

if docker network inspect qa-lab-sonar >/dev/null 2>&1; then
  log "Removing network qa-lab-sonar"
  docker network rm qa-lab-sonar >/dev/null 2>&1 || true
fi

if [[ "${KEEP_JENKINS}" != "1" ]]; then
  if docker inspect "${JENKINS_CONTAINER}" >/dev/null 2>&1; then
    log "Removing Jenkins container '${JENKINS_CONTAINER}'"
    docker rm -f "${JENKINS_CONTAINER}" >/dev/null 2>&1 || true
  fi
else
  log "Keeping Jenkins container (KEEP_JENKINS=1)"
fi

log "Removing loan-service lab images..."
while IFS= read -r img; do
  [[ -z "${img}" ]] && continue
  safe_rmi "${img}"
done < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'loan-service|k3d-qa-registry|k3d-qa-lab-registry' || true)

log "Removing dangling images and stopped leftovers from this teardown..."
docker container prune -f >/dev/null 2>&1 || true
docker image prune -f >/dev/null 2>&1 || true
docker builder prune -f >/dev/null 2>&1 || true

# Named volumes created by this lab's compose project (not a global volume prune)
while IFS= read -r vol; do
  [[ -z "${vol}" ]] && continue
  log "Removing volume ${vol}"
  docker volume rm "${vol}" >/dev/null 2>&1 || true
done < <(docker volume ls -q | grep -E 'sonar-db|sonar-data|sonar-logs|sonar-extensions|qa-architecture-lab_sonar' || true)

if [[ "${PURGE}" == "1" ]]; then
  log "Purge: removing reusable lab images and Jenkins home volume..."
  if [[ "${KEEP_JENKINS}" != "1" ]]; then
    docker volume rm jenkins_home >/dev/null 2>&1 || true
  fi
  while IFS= read -r img; do
    [[ -z "${img}" ]] && continue
    safe_rmi "${img}"
  done < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E \
    '^sonarqube:|^postgres:16|^jenkins/jenkins:|^ghcr.io/k3d-io/k3d:|^rancher/k3s:|^rancher/mirrored-library-traefik:|^rancher/local-path-provisioner:' \
    || true)
  docker image prune -f >/dev/null 2>&1 || true
fi

echo ""
log "Disk after cleanup:"
df_line

cat <<EOF

Lab is down.

  Start again:     ./scripts/up.sh
  Aggressive reclaim (lab images + Jenkins home):
                   ./scripts/down.sh --purge

EOF
