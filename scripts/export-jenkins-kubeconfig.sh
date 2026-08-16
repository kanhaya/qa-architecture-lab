#!/usr/bin/env bash
set -euo pipefail

# Generates a kubeconfig for Jenkins running inside Docker on the k3d network.
# Upload the output file to Jenkins as a Secret file credential with ID: k3d-kubeconfig
#
# Usage:
#   ./scripts/export-jenkins-kubeconfig.sh > jenkins-kubeconfig.yaml
#   # Jenkins → Manage Credentials → Add Secret file → ID: k3d-kubeconfig

K3D_CLUSTER="${K3D_CLUSTER:-qa-cluster}"
KUBE_CONTEXT="k3d-${K3D_CLUSTER}"
KUBE_SERVER="https://k3d-${K3D_CLUSTER}-serverlb:6443"
OUTPUT="${1:-}"

if ! command -v k3d >/dev/null 2>&1; then
  echo "ERROR: k3d is not installed." >&2
  exit 1
fi

if ! k3d cluster list 2>/dev/null | grep -q "${K3D_CLUSTER}"; then
  echo "ERROR: k3d cluster '${K3D_CLUSTER}' not found." >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

k3d kubeconfig get "${K3D_CLUSTER}" > "${TMP}"
kubectl config set-cluster "${KUBE_CONTEXT}" \
  --server="${KUBE_SERVER}" \
  --kubeconfig="${TMP}"
kubectl config use-context "${KUBE_CONTEXT}" --kubeconfig="${TMP}"

if [[ -n "${OUTPUT}" ]]; then
  cp "${TMP}" "${OUTPUT}"
  echo "Wrote ${OUTPUT}" >&2
  echo "Upload to Jenkins credential ID: k3d-kubeconfig" >&2
else
  cat "${TMP}"
fi
