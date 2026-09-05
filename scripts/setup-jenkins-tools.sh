#!/usr/bin/env bash
set -euo pipefail

# Install Docker CLI, Maven, and kubectl in the Jenkins controller container
# and allow the jenkins user to talk to the mounted Docker socket.

JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"

log() {
  echo "[setup-jenkins-tools] $*"
}

if ! docker inspect "${JENKINS_CONTAINER}" >/dev/null 2>&1; then
  log "ERROR: container '${JENKINS_CONTAINER}' not found."
  exit 1
fi

log "Installing pipeline tools in ${JENKINS_CONTAINER}..."
docker exec -u 0 "${JENKINS_CONTAINER}" bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if command -v docker >/dev/null && command -v mvn >/dev/null && command -v kubectl >/dev/null; then
  echo "docker, mvn, and kubectl already installed."
else
  apt-get update -qq
  apt-get install -y --no-install-recommends maven ca-certificates curl

  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64) DOCKER_ARCH=x86_64; KUBE_ARCH=amd64 ;;
    aarch64) DOCKER_ARCH=aarch64; KUBE_ARCH=arm64 ;;
    *) echo "Unsupported arch ${ARCH}" >&2; exit 1 ;;
  esac

  if ! command -v docker >/dev/null; then
    curl -fsSL "https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-27.5.1.tgz" \
      | tar -xz -C /tmp
    mv /tmp/docker/docker /usr/local/bin/docker
    rm -rf /tmp/docker
    chmod +x /usr/local/bin/docker
  fi

  if ! command -v kubectl >/dev/null; then
    KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KVER}/bin/linux/${KUBE_ARCH}/kubectl"
    chmod +x /usr/local/bin/kubectl
  fi
fi

if [[ -S /var/run/docker.sock ]]; then
  chmod 666 /var/run/docker.sock || true
fi

echo "=== versions ==="
docker --version
mvn -version | head -n 1
kubectl version --client
'
log "Tools ready. Rebuild the Jenkins job."
