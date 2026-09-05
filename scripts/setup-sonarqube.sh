#!/usr/bin/env bash
set -euo pipefail

# Starts local SonarQube (Community LTS), waits until it is UP, then:
#   - changes the default admin password
#   - creates project com.qa:qa-architecture-lab
#   - provisions quality gate qa-lab-new-code with New Code conditions
#   - generates a token named "jenkins"
#   - connects the Jenkins container to the Sonar Docker network when present

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.sonarqube.yml"
SONAR_URL="${SONAR_URL:-http://localhost:9000}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-com.qa:qa-architecture-lab}"
SONAR_PROJECT_NAME="${SONAR_PROJECT_NAME:-qa-architecture-lab}"
QUALITY_GATE_NAME="${QUALITY_GATE_NAME:-qa-lab-new-code}"
TOKEN_NAME="${TOKEN_NAME:-jenkins}"
WAIT_SECONDS="${WAIT_SECONDS:-300}"
DEFAULT_ADMIN_PASSWORD="admin"
SONAR_ADMIN_PASSWORD="${SONAR_ADMIN_PASSWORD:-QALabAdmin!9000}"

log() {
  echo "[setup-sonarqube] $*"
}

sonar_status() {
  curl -sf "${SONAR_URL}/api/system/status" 2>/dev/null || true
}

wait_for_sonar() {
  local elapsed=0
  log "Waiting for SonarQube at ${SONAR_URL} (up to ${WAIT_SECONDS}s)..."
  while [[ "${elapsed}" -lt "${WAIT_SECONDS}" ]]; do
    local body
    body="$(sonar_status)"
    if echo "${body}" | grep -q '"status":"UP"'; then
      log "SonarQube is UP."
      return 0
    fi
    if [[ -n "${body}" ]]; then
      log "Status: ${body}"
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  log "ERROR: SonarQube did not become UP within ${WAIT_SECONDS}s."
  log "Check: docker compose -f ${COMPOSE_FILE} logs sonarqube"
  exit 1
}

# Usage: api USER PASS METHOD PATH [curl --data args...]
api() {
  local user="$1"
  local pass="$2"
  local method="$3"
  local path="$4"
  shift 4
  curl -sf -u "${user}:${pass}" -X "${method}" "${SONAR_URL}${path}" "$@"
}

api_ok() {
  local user="$1"
  local pass="$2"
  local method="$3"
  local path="$4"
  shift 4
  curl -sS -o /tmp/sonar-api-body -w "%{http_code}" -u "${user}:${pass}" \
    -X "${method}" "${SONAR_URL}${path}" "$@" 
}

json_field() {
  local json="$1"
  local field="$2"
  python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "${field}" <<<"${json}"
}

create_condition() {
  local user="$1"
  local pass="$2"
  local metric="$3"
  local op="$4"
  local error="$5"
  local code
  code="$(api_ok "${user}" "${pass}" POST "/api/qualitygates/create_condition" \
    --data-urlencode "gateName=${QUALITY_GATE_NAME}" \
    --data-urlencode "metric=${metric}" \
    --data-urlencode "op=${op}" \
    --data-urlencode "error=${error}")"
  if [[ "${code}" == "200" ]]; then
    log "  condition ${metric} ${op} ${error}"
    return 0
  fi
  local body
  body="$(cat /tmp/sonar-api-body 2>/dev/null || true)"
  if echo "${body}" | grep -qiE 'already exists|already been used'; then
    log "  condition ${metric} already set"
    return 0
  fi
  if echo "${body}" | grep -qiE 'Unknown metric|Metric .* not found|not found'; then
    log "  skip ${metric} (not available on this SonarQube version)"
    return 0
  fi
  log "  WARNING: could not set ${metric} (HTTP ${code}): ${body}"
}

log "Starting SonarQube stack..."
docker compose -f "${COMPOSE_FILE}" up -d

wait_for_sonar

auth_valid() {
  local user="$1"
  local pass="$2"
  local body
  body="$(api "${user}" "${pass}" GET "/api/authentication/validate" 2>/dev/null || true)"
  echo "${body}" | grep -q '"valid":true'
}

AUTH_USER="admin"
AUTH_PASS=""

if auth_valid "${AUTH_USER}" "${SONAR_ADMIN_PASSWORD}"; then
  AUTH_PASS="${SONAR_ADMIN_PASSWORD}"
  log "Authenticated with SONAR_ADMIN_PASSWORD."
elif auth_valid "${AUTH_USER}" "${DEFAULT_ADMIN_PASSWORD}"; then
  log "Changing default admin password..."
  if api "${AUTH_USER}" "${DEFAULT_ADMIN_PASSWORD}" POST "/api/users/change_password" \
      --data-urlencode "login=admin" \
      --data-urlencode "previousPassword=${DEFAULT_ADMIN_PASSWORD}" \
      --data-urlencode "password=${SONAR_ADMIN_PASSWORD}"; then
    AUTH_PASS="${SONAR_ADMIN_PASSWORD}"
    log "Admin password updated (SONAR_ADMIN_PASSWORD / default QALabAdmin!9000)."
  else
    log "ERROR: Failed to change default admin password."
    exit 1
  fi
else
  log "ERROR: Cannot authenticate as admin."
  log "If you already changed the password, export SONAR_ADMIN_PASSWORD and re-run."
  exit 1
fi

log "Creating project ${SONAR_PROJECT_KEY}..."
create_code="$(api_ok "${AUTH_USER}" "${AUTH_PASS}" POST "/api/projects/create" \
  --data-urlencode "name=${SONAR_PROJECT_NAME}" \
  --data-urlencode "project=${SONAR_PROJECT_KEY}")"
if [[ "${create_code}" != "200" ]]; then
  body="$(cat /tmp/sonar-api-body 2>/dev/null || true)"
  if echo "${body}" | grep -qiE 'already exists|key already exists'; then
    log "Project already exists."
  else
    log "WARNING: project create HTTP ${create_code}: ${body}"
  fi
fi

log "Setting New Code Period to previous version..."
api "${AUTH_USER}" "${AUTH_PASS}" POST "/api/new_code_periods/set" \
  --data-urlencode "project=${SONAR_PROJECT_KEY}" \
  --data-urlencode "type=PREVIOUS_VERSION" >/dev/null || \
  log "WARNING: could not set New Code Period (API may differ on this version)."

log "Creating quality gate ${QUALITY_GATE_NAME}..."
qg_code="$(api_ok "${AUTH_USER}" "${AUTH_PASS}" POST "/api/qualitygates/create" \
  --data-urlencode "name=${QUALITY_GATE_NAME}")"
if [[ "${qg_code}" != "200" ]]; then
  body="$(cat /tmp/sonar-api-body 2>/dev/null || true)"
  if echo "${body}" | grep -qiE 'already been used|already exists'; then
    log "Quality gate already exists."
  else
    log "WARNING: quality gate create HTTP ${qg_code}: ${body}"
  fi
fi

log "Provisioning New Code conditions..."
# Coverage on new code >= 80% (fail if below)
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_coverage" "LT" "80"
# Duplicated lines on new code <= 3%
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_duplicated_lines_density" "GT" "3"
# New vulnerabilities = 0
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_vulnerabilities" "GT" "0"
# New blocker / critical issues = 0 (legacy + software-quality metric names)
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_blocker_violations" "GT" "0"
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_critical_violations" "GT" "0"
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_software_quality_blocker_issues" "GT" "0"
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_software_quality_high_issues" "GT" "0"
# Security hotspots reviewed = 100%
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_security_hotspots_reviewed" "LT" "100"
# Maintainability / reliability / security ratings = A (1)
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_reliability_rating" "GT" "1"
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_security_rating" "GT" "1"
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_maintainability_rating" "GT" "1"
create_condition "${AUTH_USER}" "${AUTH_PASS}" "new_sqale_rating" "GT" "1"

log "Attaching quality gate to project..."
api "${AUTH_USER}" "${AUTH_PASS}" POST "/api/qualitygates/select" \
  --data-urlencode "projectKey=${SONAR_PROJECT_KEY}" \
  --data-urlencode "gateName=${QUALITY_GATE_NAME}" >/dev/null || \
  log "WARNING: could not select quality gate for project."

log "Generating token ${TOKEN_NAME}..."
api "${AUTH_USER}" "${AUTH_PASS}" POST "/api/user_tokens/revoke" \
  --data-urlencode "name=${TOKEN_NAME}" >/dev/null 2>&1 || true
token_json="$(api "${AUTH_USER}" "${AUTH_PASS}" POST "/api/user_tokens/generate" \
  --data-urlencode "name=${TOKEN_NAME}")"
SONAR_TOKEN="$(json_field "${token_json}" "token")"
if [[ -z "${SONAR_TOKEN}" ]]; then
  log "ERROR: token generate did not return a token: ${token_json}"
  exit 1
fi

JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"
if docker inspect "${JENKINS_CONTAINER}" >/dev/null 2>&1; then
  bash "${SCRIPT_DIR}/setup-jenkins-sonar-network.sh"
else
  log "Jenkins container '${JENKINS_CONTAINER}' not found; skip network attach."
  log "Later: JENKINS_CONTAINER=jenkins ./scripts/setup-jenkins-sonar-network.sh"
fi

cat <<EOF

SonarQube is ready.

  UI:            ${SONAR_URL}
  Login:         admin
  Password:      (SONAR_ADMIN_PASSWORD, default QALabAdmin!9000)
  Project key:   ${SONAR_PROJECT_KEY}
  Quality gate:  ${QUALITY_GATE_NAME}
  Jenkins URL:   http://sonarqube:9000  (from the Jenkins container)

Add a Jenkins credential:
  Kind: Secret text
  ID:   SONAR_TOKEN
  Secret:
    ${SONAR_TOKEN}

Local scan (after mvn verify):
  mvn -pl loan-service -am sonar:sonar -Dsonar.token=${SONAR_TOKEN}

Community Edition does not decorate GitHub PR lines. Jenkins job status
and the SonarQube UI are the review signals. New Code conditions apply to
the project's New Code Period (previous version), not a PR diff.

EOF
