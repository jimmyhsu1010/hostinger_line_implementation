#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
REPO_RAW_BASE="${REPO_RAW_BASE:-}"

# Preferred path: run from a cloned private repo.
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/one-click-install.sh" ]; then
  exec bash "$SCRIPT_DIR/one-click-install.sh" "$@"
fi

# Backward-compatible raw mode. This only works for public repos, or private repos
# when curl is configured with auth outside this script. For private repos, clone first.
if [ -n "$REPO_RAW_BASE" ]; then
  echo "Downloading one-click installer from REPO_RAW_BASE..."
  curl -fsSL "$REPO_RAW_BASE/scripts/one-click-install.sh" | bash -s -- "$@"
  exit $?
fi

echo "ERROR: Cannot locate one-click-install.sh." >&2
echo "Clone the private repo first, then run:" >&2
echo "  cd hostinger_line_implementation && bash scripts/one-click-install.sh" >&2
exit 1
