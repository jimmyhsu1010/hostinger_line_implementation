#!/usr/bin/env bash
set -euo pipefail

TARGET_ADAPTER="${TARGET_ADAPTER:-/opt/hermes/plugins/platforms/line/adapter.py}"
TARGET_PLUGIN="${TARGET_PLUGIN:-$(dirname "$TARGET_ADAPTER")/plugin.yaml}"
REPO_RAW_BASE="${REPO_RAW_BASE:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
LOCAL_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd 2>/dev/null || true)"
TMP_FILE="$(mktemp)"
TMP_PLUGIN="$(mktemp)"
STAMP="$(date +%Y%m%d_%H%M%S)"

cleanup() { rm -f "$TMP_FILE" "$TMP_PLUGIN"; }
trap cleanup EXIT

echo "[1/6] Preparing target plugin directory..."
mkdir -p "$(dirname "$TARGET_ADAPTER")" "$(dirname "$TARGET_PLUGIN")"

if [ -f "$LOCAL_REPO_ROOT/line/adapter.py" ]; then
  echo "[2/6] Using local adapter: $LOCAL_REPO_ROOT/line/adapter.py"
  cp "$LOCAL_REPO_ROOT/line/adapter.py" "$TMP_FILE"
elif [ -n "$REPO_RAW_BASE" ]; then
  echo "[2/6] Downloading adapter from: $REPO_RAW_BASE/line/adapter.py"
  curl -fsSL "$REPO_RAW_BASE/line/adapter.py" -o "$TMP_FILE"
else
  echo "ERROR: No local line/adapter.py found and REPO_RAW_BASE is not set." >&2
  echo "For private repos, clone the repo first, then run: bash scripts/one-click-install.sh" >&2
  echo "Public/raw mode is only for public repos or authenticated curl setups." >&2
  exit 1
fi

if [ -f "$LOCAL_REPO_ROOT/line/plugin.yaml" ]; then
  echo "[3/6] Using local plugin metadata: $LOCAL_REPO_ROOT/line/plugin.yaml"
  cp "$LOCAL_REPO_ROOT/line/plugin.yaml" "$TMP_PLUGIN"
elif [ -n "$REPO_RAW_BASE" ]; then
  echo "[3/6] Downloading plugin metadata from: $REPO_RAW_BASE/line/plugin.yaml"
  curl -fsSL "$REPO_RAW_BASE/line/plugin.yaml" -o "$TMP_PLUGIN"
else
  echo "ERROR: No local line/plugin.yaml found and REPO_RAW_BASE is not set." >&2
  echo "For private repos, clone the repo first, then run: bash scripts/one-click-install.sh" >&2
  exit 1
fi

echo "[4/6] Syntax checking downloaded/local adapter..."
PYTHONPYCACHEPREFIX=/tmp/hermes_pycache python3 -m py_compile "$TMP_FILE"

echo "[5/6] Backing up current LINE plugin files when present..."
if [ -f "$TARGET_ADAPTER" ]; then
  cp "$TARGET_ADAPTER" "${TARGET_ADAPTER}.bak.${STAMP}"
  echo "Adapter backup: ${TARGET_ADAPTER}.bak.${STAMP}"
else
  echo "No existing adapter found; installing fresh: $TARGET_ADAPTER"
fi
if [ -f "$TARGET_PLUGIN" ]; then
  cp "$TARGET_PLUGIN" "${TARGET_PLUGIN}.bak.${STAMP}"
  echo "Plugin metadata backup: ${TARGET_PLUGIN}.bak.${STAMP}"
else
  echo "No existing plugin metadata found; installing fresh: $TARGET_PLUGIN"
fi

echo "[6/6] Installing LINE adapter and plugin metadata..."
cp "$TMP_FILE" "$TARGET_ADAPTER"
cp "$TMP_PLUGIN" "$TARGET_PLUGIN"
PYTHONPYCACHEPREFIX=/tmp/hermes_pycache python3 -m py_compile "$TARGET_ADAPTER"

if command -v sha256sum >/dev/null 2>&1; then
  echo "Installed sha256: $(sha256sum "$TARGET_ADAPTER" | awk '{print $1}')"
fi

echo "OK: LINE adapter installed. Restart the Hermes container/gateway for changes to take effect."
