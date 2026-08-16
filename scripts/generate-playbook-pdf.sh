#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(cd "${SCRIPT_DIR}/../docs" && pwd)"
OUTPUT="${DOCS_DIR}/QA-Architecture-Lab-Playbook.pdf"

if ! command -v npx >/dev/null 2>&1; then
  echo "ERROR: npx (Node.js) is required to generate the PDF." >&2
  exit 1
fi

log() {
  echo "[generate-playbook-pdf] $*"
}

log "Generating PDF from docs/BUILD-GUIDE.md..."
cd "${DOCS_DIR}"

npx --yes md-to-pdf BUILD-GUIDE.md \
  --stylesheet pdf-style.css \
  --pdf-options '{"format":"A4","margin":{"top":"20mm","bottom":"20mm","left":"22mm","right":"22mm"},"printBackground":true}'

mv -f BUILD-GUIDE.pdf "${OUTPUT}"
log "PDF created: ${OUTPUT}"
