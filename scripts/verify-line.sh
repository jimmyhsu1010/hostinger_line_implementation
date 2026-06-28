#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/data/.env}"
ADAPTER="${TARGET_ADAPTER:-/opt/hermes/plugins/platforms/line/adapter.py}"
LINE_PORT_VALUE="${LINE_PORT:-}"
LINE_PUBLIC_URL_VALUE="${LINE_PUBLIC_URL:-}"

load_env_value() {
  local key="$1"
  if [ -n "${!key:-}" ]; then printf '%s' "${!key}"; return 0; fi
  if [ -f "$ENV_FILE" ]; then
    awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/, ""); print; exit}' "$ENV_FILE" | sed 's/^"//; s/"$//'
  fi
}

LINE_PORT_VALUE="$(load_env_value LINE_PORT)"
LINE_PUBLIC_URL_VALUE="$(load_env_value LINE_PUBLIC_URL)"
LINE_CHANNEL_ACCESS_TOKEN_VALUE="$(load_env_value LINE_CHANNEL_ACCESS_TOKEN)"
LINE_CHANNEL_SECRET_VALUE="$(load_env_value LINE_CHANNEL_SECRET)"
LINE_PORT_VALUE="${LINE_PORT_VALUE:-8646}"

echo "== Env check =="
[ -n "$LINE_CHANNEL_ACCESS_TOKEN_VALUE" ] && echo "LINE_CHANNEL_ACCESS_TOKEN=SET" || echo "LINE_CHANNEL_ACCESS_TOKEN=MISSING"
[ -n "$LINE_CHANNEL_SECRET_VALUE" ] && echo "LINE_CHANNEL_SECRET=SET" || echo "LINE_CHANNEL_SECRET=MISSING"
[ -n "$LINE_PUBLIC_URL_VALUE" ] && echo "LINE_PUBLIC_URL=$LINE_PUBLIC_URL_VALUE" || echo "LINE_PUBLIC_URL=MISSING"
echo "LINE_PORT=$LINE_PORT_VALUE"

echo
if [ -f "$ADAPTER" ]; then
  echo "== Adapter syntax =="
  PYTHONPYCACHEPREFIX=/tmp/hermes_pycache python3 -m py_compile "$ADAPTER"
  echo "adapter_py_compile=OK"
else
  echo "adapter_py_compile=SKIPPED (not found: $ADAPTER)"
fi

echo
LOCAL_HEALTH="http://127.0.0.1:${LINE_PORT_VALUE}/line/webhook/health"
echo "== Local health =="
echo "$LOCAL_HEALTH"
if curl -fsS --max-time 5 "$LOCAL_HEALTH"; then
  echo
  echo "local_health=OK"
else
  echo
  echo "local_health=FAILED"
fi

if [ -n "$LINE_PUBLIC_URL_VALUE" ]; then
  PUBLIC_BASE="${LINE_PUBLIC_URL_VALUE%/}"
  PUBLIC_HEALTH="$PUBLIC_BASE/line/webhook/health"
  echo
  echo "== Public health =="
  echo "$PUBLIC_HEALTH"
  if curl -fsS --max-time 10 "$PUBLIC_HEALTH"; then
    echo
    echo "public_health=OK"
  else
    echo
    echo "public_health=FAILED"
  fi
  echo
  echo "LINE webhook URL: $PUBLIC_BASE/line/webhook"
fi
