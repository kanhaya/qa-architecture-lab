#!/usr/bin/env bash
set -euo pipefail

# Connects a Jenkins Docker container to the SonarQube compose network so it can
# resolve http://sonarqube:9000 from inside the Jenkins container.

JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"
SONAR_NETWORK="${SONAR_NETWORK:-qa-lab-sonar}"

log() {
  echo "[setup-jenkins-sonar-network] $*"
}

if ! docker inspect "${JENKINS_CONTAINER}" >/dev/null 2>&1; then
  log "ERROR: Jenkins container '${JENKINS_CONTAINER}' not found."
  log "Set JENKINS_CONTAINER to your Jenkins container name."
  exit 1
fi

if ! docker network inspect "${SONAR_NETWORK}" >/dev/null 2>&1; then
  log "ERROR: SonarQube network '${SONAR_NETWORK}' not found."
  log "Start SonarQube first: ./scripts/setup-sonarqube.sh"
  exit 1
fi

if docker inspect "${JENKINS_CONTAINER}" \
    --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
    | grep -q "${SONAR_NETWORK}"; then
  log "Jenkins is already connected to ${SONAR_NETWORK}."
else
  log "Connecting Jenkins to ${SONAR_NETWORK}..."
  docker network connect "${SONAR_NETWORK}" "${JENKINS_CONTAINER}"
  log "Connected."
fi

log ""
log "Jenkins can reach SonarQube at http://sonarqube:9000"
log "Host browser: http://localhost:9000"
log "Store a user token in Jenkins as secret text credential SONAR_TOKEN."
