#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAMESPACE="${NAMESPACE:-qa-lab}"
DEPLOYMENT="${DEPLOYMENT:-loan-service}"
BASE_URL="${BASE_URL:-http://localhost:30080}"
TIMEOUT="${TIMEOUT:-180}"
K3D_CLUSTER="${K3D_CLUSTER:-qa-cluster}"
REGISTRY="${REGISTRY:-localhost:5001}"
IMAGE_NAME="${IMAGE_NAME:-loan-service}"
IMAGE_TAG="${IMAGE_TAG:-1.0}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
CLUSTER_IMAGE="k3d-qa-registry:5000/${IMAGE_NAME}:${IMAGE_TAG}"

log() {
  echo "[deploy-and-test] $*"
}

cd "${PROJECT_ROOT}"

log "Step 1: Building application..."
./mvnw clean package -pl loan-service -am -DskipTests -q

log "Step 2: Building Docker image ${FULL_IMAGE}..."
docker build -t "${FULL_IMAGE}" .

if command -v k3d >/dev/null 2>&1 && k3d cluster list 2>/dev/null | grep -q "${K3D_CLUSTER}"; then
  log "Step 3: Pushing image to k3d registry..."
  docker push "${FULL_IMAGE}"
else
  log "Step 3: Skipping registry push (k3d cluster '${K3D_CLUSTER}' not found)"
fi

log "Step 4: Deploying to Kubernetes..."
kubectl apply -f k8s/
kubectl set image deployment/"${DEPLOYMENT}" \
  "${DEPLOYMENT}=${CLUSTER_IMAGE}" \
  -n "${NAMESPACE}" 2>/dev/null || true

log "Step 5: Waiting for rollout..."
kubectl rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout="${TIMEOUT}s"

log "Step 6: Validating deployment..."
NAMESPACE="${NAMESPACE}" DEPLOYMENT="${DEPLOYMENT}" BASE_URL="${BASE_URL}" TIMEOUT="${TIMEOUT}" \
  bash "${SCRIPT_DIR}/validate-deployment.sh"

log "Step 7: Running smoke tests..."
export BASE_URL
./mvnw test -pl tests -Dgroups=smoke -q

log "Deploy and test completed successfully"
