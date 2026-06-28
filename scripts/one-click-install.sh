#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { printf '\n== %s ==\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

find_compose_file() {
  if [ -n "${COMPOSE_FILE:-}" ] && [ -f "$COMPOSE_FILE" ]; then
    printf '%s\n' "$COMPOSE_FILE"
    return 0
  fi

  local candidates=(
    "$ROOT_DIR/docker-compose.yml"
    "$ROOT_DIR/compose.yml"
    "$ROOT_DIR/../docker-compose.yml"
    "$ROOT_DIR/../compose.yml"
    "/opt/hermes/docker-compose.yml"
    "/opt/data/docker-compose.yml"
  )

  local c
  for c in "${candidates[@]}"; do
    if [ -f "$c" ] && grep -q 'PathPrefix(`/line' "$c" 2>/dev/null; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

log "Hostinger LINE Hermes one-click install"
echo "Repo: $ROOT_DIR"

log "1/5 Install verified LINE adapter"
bash "$SCRIPT_DIR/install-line-adapter.sh"

log "2/5 Apply safe Hermes config defaults"
bash "$SCRIPT_DIR/configure-hostinger-line.sh" "$@"

log "3/5 Check/fix Hostinger Traefik LINE route"
if compose_file="$(find_compose_file)"; then
  echo "Compose file: $compose_file"
  if grep -q 'PathPrefix(`/line/webhook`)' "$compose_file" 2>/dev/null; then
    bash "$SCRIPT_DIR/fix-traefik-line-route.sh" "$compose_file"
  elif grep -q 'PathPrefix(`/line`)' "$compose_file" 2>/dev/null; then
    echo "Traefik LINE route already uses PathPrefix(\`/line\`). No change needed."
  else
    warn "Compose file found, but no recognizable LINE PathPrefix rule was found. Skipping route edit."
  fi
else
  warn "No compose file found from this environment."
  warn "If you cloned this repo inside the container, this is normal. Make sure Hostinger compose already uses PathPrefix(\`/line\`)."
  warn "To fix from the host, run: COMPOSE_FILE=/path/to/docker-compose.yml bash scripts/one-click-install.sh"
fi

log "4/5 Verify LINE adapter/env/health"
bash "$SCRIPT_DIR/verify-line.sh" || true

log "5/5 Done"
echo "Next steps:"
echo "1. Restart the Hermes container or gateway."
echo "2. Confirm health: <LINE_PUBLIC_URL>/line/webhook/health"
echo "3. Set LINE Developers webhook: <LINE_PUBLIC_URL>/line/webhook"
echo "4. Send a LINE test message."
