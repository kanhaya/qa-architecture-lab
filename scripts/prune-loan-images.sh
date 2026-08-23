#!/usr/bin/env bash
# Remove old local loan-service image tags. Keep the N newest numeric tags,
# the current Jenkins build (if set), and the :1.0 lab default.
set -euo pipefail

KEEP_IMAGES="${KEEP_IMAGES:-3}"
IMAGE_NAME="${IMAGE_NAME:-loan-service}"
CURRENT_BUILD="${BUILD_NUMBER:-}"

numeric_tags="$(
  docker images --format '{{.Repository}} {{.Tag}}' \
    | awk -v name="${IMAGE_NAME}" '$1 ~ name && $2 ~ /^[0-9]+$/ { print $2 }' \
    | sort -n -u
)"

keep_list="$(printf '%s\n' "${numeric_tags}" | tail -n "${KEEP_IMAGES}")"
if [ -n "${CURRENT_BUILD}" ]; then
  keep_list="$(printf '%s\n%s\n' "${keep_list}" "${CURRENT_BUILD}" | sort -u)"
fi

should_keep() {
  tag="$1"
  [ "${tag}" = "1.0" ] && return 0
  [ "${tag}" = "latest" ] && return 0
  printf '%s\n' "${keep_list}" | grep -qx "${tag}"
}

removed=0
docker images --format '{{.Repository}} {{.Tag}}' | while IFS=' ' read -r repo tag; do
  [ -z "${repo}" ] && continue
  [ "${tag}" = "<none>" ] && continue
  case "${repo}" in
    *"${IMAGE_NAME}"*) ;;
    *) continue ;;
  esac

  if should_keep "${tag}"; then
    echo "Keeping ${repo}:${tag}"
    continue
  fi

  echo "Removing ${repo}:${tag}"
  docker rmi "${repo}:${tag}" || true
done

echo "Pruned old ${IMAGE_NAME} tags; reclaiming dangling layers:"
docker image prune -f
