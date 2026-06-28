#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${1:-docker-compose.yml}"
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "ERROR: compose file not found: $COMPOSE_FILE" >&2
  echo "Usage: bash scripts/fix-traefik-line-route.sh /path/to/docker-compose.yml" >&2
  exit 1
fi

BACKUP="${COMPOSE_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
cp "$COMPOSE_FILE" "$BACKUP"

python3 - "$COMPOSE_FILE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = "PathPrefix(`/line/webhook`)"
new = "PathPrefix(`/line`)"
if old not in s:
    print(f"No {old} found; file may already be fixed or uses a different style.")
else:
    p.write_text(s.replace(old, new))
    print(f"Updated {old} -> {new}")
PY

echo "Backup: $BACKUP"
echo "If this compose file is active, redeploy/restart the service from Hostinger or Docker."
