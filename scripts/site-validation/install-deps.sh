#!/usr/bin/env bash
# =============================================================================
# On-demand installer for site validation tools (puppeteer, ffmpeg, etc.)
# Compartmentalized: does NOT modify devcontainer.json — only used when
# explicitly invoked for retrospective content validation sessions.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Site Validation Tool Installer ==="
echo "Installing to: ${SCRIPT_DIR}"
echo ""

# --- System packages (apt-get) ---
install_system_deps() {
  local needs_install=()

  if ! command -v ffmpeg &>/dev/null; then
    needs_install+=("ffmpeg")
  else
    echo "✓ ffmpeg already installed ($(ffmpeg -version 2>&1 | head -1))"
  fi

  if ! command -v convert &>/dev/null; then
    needs_install+=("imagemagick")
  else
    echo "✓ imagemagick already installed ($(convert --version 2>&1 | head -1))"
  fi

  if ! command -v zip &>/dev/null; then
    needs_install+=("zip")
  else
    echo "✓ zip already installed"
  fi

  # Chromium dependencies for puppeteer headless
  local chromium_deps=(
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1
    libpango-1.0-0 libcairo2 libasound2 libxshmfence1
  )

  for dep in "${chromium_deps[@]}"; do
    if ! dpkg -s "$dep" &>/dev/null 2>&1; then
      needs_install+=("$dep")
    fi
  done

  if [ ${#needs_install[@]} -gt 0 ]; then
    echo "Installing system packages: ${needs_install[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${needs_install[@]}"
    echo "✓ System packages installed"
  else
    echo "✓ All system packages already present"
  fi
}

# --- Node.js packages (local npm install) ---
install_node_deps() {
  cd "${SCRIPT_DIR}"

  if [ ! -f package.json ]; then
    echo "Initializing local package.json..."
    cat > package.json <<'PKGJSON'
{
  "name": "site-validation-tools",
  "version": "1.0.0",
  "private": true,
  "description": "On-demand tools for retrospective content validation (screenshots, GIF, video, broken links)",
  "dependencies": {
    "puppeteer": "^23.0.0",
    "serve": "^14.0.0"
  }
}
PKGJSON
  fi

  if [ ! -d node_modules ] || [ ! -f node_modules/.package-lock.json ]; then
    echo "Installing Node.js dependencies..."
    if [ -f package-lock.json ]; then
      npm ci --no-audit --no-fund 2>&1 | tail -3
    else
      npm install --no-audit --no-fund 2>&1 | tail -3
    fi
    echo "✓ Node.js packages installed"
  else
    echo "✓ Node.js packages already installed"
  fi
}

# --- Verify all tools ---
verify_tools() {
  echo ""
  echo "=== Verification ==="
  local ok=true

  if command -v ffmpeg &>/dev/null; then
    echo "✓ ffmpeg: $(ffmpeg -version 2>&1 | head -1 | cut -d' ' -f1-3)"
  else
    echo "✗ ffmpeg: NOT FOUND"; ok=false
  fi

  if command -v convert &>/dev/null; then
    echo "✓ imagemagick: $(convert --version 2>&1 | head -1 | awk '{print $1,$2,$3}')"
  else
    echo "✗ imagemagick: NOT FOUND"; ok=false
  fi

  if [ -x "${SCRIPT_DIR}/node_modules/.bin/puppeteer" ] || [ -d "${SCRIPT_DIR}/node_modules/puppeteer" ]; then
    local pver
    pver=$(node -e "console.log(require('${SCRIPT_DIR}/node_modules/puppeteer/package.json').version)" 2>/dev/null || echo "unknown")
    echo "✓ puppeteer: v${pver}"
  else
    echo "✗ puppeteer: NOT FOUND"; ok=false
  fi

  if [ -x "${SCRIPT_DIR}/node_modules/.bin/serve" ]; then
    echo "✓ serve: $(${SCRIPT_DIR}/node_modules/.bin/serve --version 2>&1 | head -1)"
  else
    echo "✗ serve: NOT FOUND"; ok=false
  fi

  if command -v zip &>/dev/null; then
    echo "✓ zip: $(zip --version 2>&1 | head -2 | tail -1 | awk '{print $1,$2}')"
  else
    echo "✗ zip: NOT FOUND"; ok=false
  fi

  echo ""
  if $ok; then
    echo "=== All tools ready ==="
  else
    echo "=== Some tools missing — check errors above ==="
    return 1
  fi
}

install_system_deps
install_node_deps
verify_tools
