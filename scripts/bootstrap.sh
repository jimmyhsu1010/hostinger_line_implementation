#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
REPO_RAW_BASE="${REPO_RAW_BASE:-}"

run_script() {
  local name="$1"
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$name" ]; then
    bash "$SCRIPT_DIR/$name"
  elif [ -n "$REPO_RAW_BASE" ]; then
    curl -fsSL "$REPO_RAW_BASE/scripts/$name" | bash
  else
    echo "ERROR: Cannot locate $name. Run from cloned repo or set REPO_RAW_BASE." >&2
    exit 1
  fi
}

echo "== Hostinger LINE Hermes bootstrap =="
run_script install-line-adapter.sh
run_script configure-hostinger-line.sh

echo
run_script verify-line.sh || true

echo
echo "Bootstrap finished. Next steps:"
echo "1. Restart the Hermes container/gateway."
echo "2. Confirm public health: <LINE_PUBLIC_URL>/line/webhook/health"
echo "3. Set LINE Developers webhook URL: <LINE_PUBLIC_URL>/line/webhook"
echo "4. Send a test message to the LINE OA."
