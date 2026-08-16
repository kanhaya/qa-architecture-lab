#!/usr/bin/env bash
set -euo pipefail

# Generates a kubeconfig for kubectl inside the Jenkins container.
# Uses the k3d Docker image + host docker socket (no Jenkins credential needed).

K3D_CLUSTER="${K3D_CLUSTER:-qa-cluster}"
KUBE_CONTEXT="${KUBE_CONTEXT:-k3d-${K3D_CLUSTER}}"
KUBE_SERVER="${KUBE_SERVER:-https://k3d-${K3D_CLUSTER}-serverlb:6443}"
K3D_IMAGE="${K3D_IMAGE:-ghcr.io/k3d-io/k3d:5.8.3}"

export KUBECONFIG="$(mktemp)"

docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "${K3D_IMAGE}" \
    kubeconfig get "${K3D_CLUSTER}" > "${KUBECONFIG}"

kubectl config set-cluster "${KUBE_CONTEXT}" \
    --server="${KUBE_SERVER}" \
    --kubeconfig="${KUBECONFIG}"

kubectl config use-context "${KUBE_CONTEXT}" --kubeconfig="${KUBECONFIG}"

echo "Kubeconfig ready: context=${KUBE_CONTEXT} server=${KUBE_SERVER}" >&2
