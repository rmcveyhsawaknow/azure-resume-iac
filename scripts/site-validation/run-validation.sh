#!/usr/bin/env bash
# =============================================================================
# run-validation.sh — Orchestrator for retrospective content validation
#
# Captures screenshots, GIF, video, and broken link reports for both the
# local development site and the deployed production site, then packages
# artifacts into zip files for inclusion in retrospective issue comments.
#
# Usage:
#   bash scripts/site-validation/run-validation.sh \
#     --phase 2 \
#     --local-dir frontend/ \
#     --live-url https://resume.ryanmcvey.me \
#     --output-base docs/retrospectives/phase-2-assets
#
# Options:
#   --phase       Phase number (used for zip naming)
#   --local-dir   Path to frontend directory to serve locally
#   --live-url    URL of deployed production site
#   --output-base Base output directory for all artifacts
#   --sections    Comma-separated section IDs (default: home,about,resume,agentgitops,projects)
#   --skip-local  Skip local site capture
#   --skip-live   Skip live site capture
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# --- Default values ---
PHASE=""
LOCAL_DIR=""
LIVE_URL=""
OUTPUT_BASE=""
SECTIONS="home,about,resume,agentgitops,projects"
SKIP_LOCAL=false
SKIP_LIVE=false

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)       PHASE="$2"; shift 2 ;;
    --local-dir)   LOCAL_DIR="$2"; shift 2 ;;
    --live-url)    LIVE_URL="$2"; shift 2 ;;
    --output-base) OUTPUT_BASE="$2"; shift 2 ;;
    --sections)    SECTIONS="$2"; shift 2 ;;
    --skip-local)  SKIP_LOCAL=true; shift ;;
    --skip-live)   SKIP_LIVE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$PHASE" || -z "$OUTPUT_BASE" ]]; then
  echo "Error: --phase and --output-base are required"
  echo "Usage: bash $0 --phase <N> --output-base <dir> [--local-dir <dir>] [--live-url <url>] [--skip-local] [--skip-live]"
  exit 1
fi

# Resolve paths relative to repo root
cd "${REPO_ROOT}"
OUTPUT_BASE="${OUTPUT_BASE%/}"
mkdir -p "${OUTPUT_BASE}"

echo "============================================"
echo "  Phase ${PHASE} Content Validation"
echo "============================================"
echo ""
echo "Output:     ${OUTPUT_BASE}/"
echo "Local dir:  ${LOCAL_DIR:-n/a}"
echo "Live URL:   ${LIVE_URL:-n/a}"
echo "Sections:   ${SECTIONS}"
echo ""

# --- Step 1: Install dependencies ---
echo "--- Installing dependencies ---"
bash "${SCRIPT_DIR}/install-deps.sh"
echo ""

CAPTURE_JS="${SCRIPT_DIR}/capture-site.js"
NODE_PATH="${SCRIPT_DIR}/node_modules"
SERVE_BIN="${SCRIPT_DIR}/node_modules/.bin/serve"
SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]]; then
    echo "Stopping local server (PID: ${SERVER_PID})..."
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# --- Step 2: Capture local site ---
if [[ "${SKIP_LOCAL}" == false && -n "${LOCAL_DIR}" ]]; then
  echo "--- Capturing local site ---"

  # Find an available port using bash built-in /dev/tcp
  PORT=8080
  while (echo >/dev/tcp/localhost/${PORT}) 2>/dev/null; do
    PORT=$((PORT + 1))
  done

  echo "Starting local server on port ${PORT}..."
  "${SERVE_BIN}" "${LOCAL_DIR}" -l "${PORT}" --no-clipboard &>/dev/null &
  SERVER_PID=$!
  sleep 3

  # Verify server is running
  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "Error: Local server failed to start"
    exit 1
  fi
  echo "Server running on http://localhost:${PORT} (PID: ${SERVER_PID})"

  NODE_PATH="${NODE_PATH}" node "${CAPTURE_JS}" \
    --url "http://localhost:${PORT}" \
    --output "${OUTPUT_BASE}/local" \
    --sections "${SECTIONS}" \
    --label "Local (develop branch)"

  # Stop server
  kill "${SERVER_PID}" 2>/dev/null || true
  wait "${SERVER_PID}" 2>/dev/null || true
  SERVER_PID=""
  echo ""
fi

# --- Step 3: Capture live site ---
if [[ "${SKIP_LIVE}" == false && -n "${LIVE_URL}" ]]; then
  echo "--- Capturing live site ---"

  NODE_PATH="${NODE_PATH}" node "${CAPTURE_JS}" \
    --url "${LIVE_URL}" \
    --output "${OUTPUT_BASE}/live" \
    --sections "${SECTIONS}" \
    --label "Live (${LIVE_URL})"

  echo ""
fi

# --- Step 4: Package zip files ---
echo "--- Packaging artifacts ---"

if [[ -d "${OUTPUT_BASE}/local" ]]; then
  ZIP_LOCAL="${OUTPUT_BASE}/phase-${PHASE}-local-site.zip"
  (cd "${OUTPUT_BASE}/local" && zip -q -r "${REPO_ROOT}/${ZIP_LOCAL}" .)
  echo "✓ ${ZIP_LOCAL} ($(du -h "${ZIP_LOCAL}" | cut -f1))"
fi

if [[ -d "${OUTPUT_BASE}/live" ]]; then
  ZIP_LIVE="${OUTPUT_BASE}/phase-${PHASE}-live-site.zip"
  (cd "${OUTPUT_BASE}/live" && zip -q -r "${REPO_ROOT}/${ZIP_LIVE}" .)
  echo "✓ ${ZIP_LIVE} ($(du -h "${ZIP_LIVE}" | cut -f1))"
fi

# --- Step 5: Generate comparison summary ---
echo ""
echo "--- Generating comparison summary ---"

SUMMARY="${OUTPUT_BASE}/comparison-summary.md"
cat > "${SUMMARY}" <<EOF
# Phase ${PHASE} Content Validation — Comparison Summary

**Generated:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Artifact Inventory

### Local Site (develop branch)
EOF

if [[ -d "${OUTPUT_BASE}/local" ]]; then
  echo "" >> "${SUMMARY}"
  echo "| File | Size |" >> "${SUMMARY}"
  echo "|---|---|" >> "${SUMMARY}"
  for f in "${OUTPUT_BASE}"/local/*; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")
    fsize=$(du -h "$f" | cut -f1)
    echo "| ${fname} | ${fsize} |" >> "${SUMMARY}"
  done
  if [[ -f "${OUTPUT_BASE}/phase-${PHASE}-local-site.zip" ]]; then
    zsize=$(du -h "${OUTPUT_BASE}/phase-${PHASE}-local-site.zip" | cut -f1)
    echo "" >> "${SUMMARY}"
    echo "**Zip:** phase-${PHASE}-local-site.zip (${zsize})" >> "${SUMMARY}"
  fi
else
  echo "" >> "${SUMMARY}"
  echo "*Skipped*" >> "${SUMMARY}"
fi

cat >> "${SUMMARY}" <<EOF

### Live Site (${LIVE_URL:-n/a})
EOF

if [[ -d "${OUTPUT_BASE}/live" ]]; then
  echo "" >> "${SUMMARY}"
  echo "| File | Size |" >> "${SUMMARY}"
  echo "|---|---|" >> "${SUMMARY}"
  for f in "${OUTPUT_BASE}"/live/*; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")
    fsize=$(du -h "$f" | cut -f1)
    echo "| ${fname} | ${fsize} |" >> "${SUMMARY}"
  done
  if [[ -f "${OUTPUT_BASE}/phase-${PHASE}-live-site.zip" ]]; then
    zsize=$(du -h "${OUTPUT_BASE}/phase-${PHASE}-live-site.zip" | cut -f1)
    echo "" >> "${SUMMARY}"
    echo "**Zip:** phase-${PHASE}-live-site.zip (${zsize})" >> "${SUMMARY}"
  fi
else
  echo "" >> "${SUMMARY}"
  echo "*Skipped*" >> "${SUMMARY}"
fi

echo "" >> "${SUMMARY}"

echo "✓ Comparison summary: ${SUMMARY}"
echo ""
echo "============================================"
echo "  Phase ${PHASE} validation complete!"
echo "  Output: ${OUTPUT_BASE}/"
echo "============================================"
