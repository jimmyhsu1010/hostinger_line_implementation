#!/usr/bin/env bash
set -euo pipefail

TARGET_ADAPTER="${TARGET_ADAPTER:-/opt/hermes/plugins/platforms/line/adapter.py}"
REPO_RAW_BASE="${REPO_RAW_BASE:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
LOCAL_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd 2>/dev/null || true)"
TMP_FILE="$(mktemp)"
BACKUP="${TARGET_ADAPTER}.bak.$(date +%Y%m%d_%H%M%S)"

cleanup() { rm -f "$TMP_FILE"; }
trap cleanup EXIT

echo "[1/5] Checking target adapter path..."
if [ ! -f "$TARGET_ADAPTER" ]; then
  echo "ERROR: LINE adapter not found: $TARGET_ADAPTER" >&2
  echo "Run this inside the Hermes container, or set TARGET_ADAPTER=/path/to/adapter.py" >&2
  exit 1
fi

if [ -f "$LOCAL_REPO_ROOT/line/adapter.py" ]; then
  echo "[2/5] Using local adapter: $LOCAL_REPO_ROOT/line/adapter.py"
  cp "$LOCAL_REPO_ROOT/line/adapter.py" "$TMP_FILE"
elif [ -n "$REPO_RAW_BASE" ]; then
  echo "[2/5] Downloading adapter from: $REPO_RAW_BASE/line/adapter.py"
  curl -fsSL "$REPO_RAW_BASE/line/adapter.py" -o "$TMP_FILE"
else
  echo "ERROR: No local line/adapter.py found and REPO_RAW_BASE is not set." >&2
  echo "For private repos, clone the repo first, then run: bash scripts/one-click-install.sh" >&2
  echo "Public/raw mode is only for public repos or authenticated curl setups." >&2
  exit 1
fi

echo "[3/5] Syntax checking downloaded/local adapter..."
PYTHONPYCACHEPREFIX=/tmp/hermes_pycache python3 -m py_compile "$TMP_FILE"

echo "[4/5] Backing up current adapter..."
cp "$TARGET_ADAPTER" "$BACKUP"
echo "Backup: $BACKUP"

echo "[5/5] Installing adapter..."
cp "$TMP_FILE" "$TARGET_ADAPTER"
PYTHONPYCACHEPREFIX=/tmp/hermes_pycache python3 -m py_compile "$TARGET_ADAPTER"

if command -v sha256sum >/dev/null 2>&1; then
  echo "Installed sha256: $(sha256sum "$TARGET_ADAPTER" | awk '{print $1}')"
fi

echo "OK: LINE adapter installed. Restart the Hermes container/gateway for changes to take effect."
