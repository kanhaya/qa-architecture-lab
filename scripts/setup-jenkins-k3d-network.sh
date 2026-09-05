#!/usr/bin/env bash
set -euo pipefail

# Connects a Jenkins Docker container to the k3d cluster network so it can:
#   - resolve qa-registry:5000
#   - reach the Loan Service NodePort at k3d-qa-lab-server-0:30080
#
# Prerequisites:
#   1. k3d cluster exists:  ./scripts/setup-k3d-cluster.sh
#   2. Jenkins runs in Docker with the Docker socket mounted (-v /var/run/docker.sock)

JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"
K3D_CLUSTER="${K3D_CLUSTER:-qa-cluster}"
K3D_NETWORK="k3d-${K3D_CLUSTER}"

log() {
  echo "[setup-jenkins-k3d-network] $*"
}

if ! docker inspect "${JENKINS_CONTAINER}" >/dev/null 2>&1; then
  log "ERROR: Jenkins container '${JENKINS_CONTAINER}' not found."
  log "Set JENKINS_CONTAINER to your Jenkins container name."
  exit 1
fi

if ! docker network inspect "${K3D_NETWORK}" >/dev/null 2>&1; then
  log "ERROR: k3d network '${K3D_NETWORK}' not found."
  log "Create the cluster first: ./scripts/setup-k3d-cluster.sh"
  exit 1
fi

if docker inspect "${JENKINS_CONTAINER}" \
    --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
    | grep -q "${K3D_NETWORK}"; then
  log "Jenkins is already connected to ${K3D_NETWORK}."
else
  log "Connecting Jenkins to ${K3D_NETWORK}..."
  docker network connect "${K3D_NETWORK}" "${JENKINS_CONTAINER}"
  log "Connected."
fi

log ""
log "Jenkins is now on the k3d network."
log "  Registry (in-cluster name): qa-registry:5000"
log "  Registry (host push port):  localhost:5001"
log "  Service URL (from Jenkins): http://k3d-qa-cluster-server-0:30080"
log "  Kubernetes API (from Jenkins): https://k3d-qa-cluster-serverlb:6443"
log ""
log "Generate kubeconfig for Jenkins credentials:"
log "  ./scripts/export-jenkins-kubeconfig.sh jenkins-kubeconfig.yaml"
