#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/data/.env}"
ADAPTER="${TARGET_ADAPTER:-/opt/hermes/plugins/platforms/line/adapter.py}"
LINE_PORT_VALUE="${LINE_PORT:-}"
LINE_PUBLIC_URL_VALUE="${LINE_PUBLIC_URL:-}"
SKIP_HEALTH=0
NON_STRICT=0

for arg in "$@"; do
  case "$arg" in
    --skip-health)
      SKIP_HEALTH=1
      ;;
    --non-strict)
      NON_STRICT=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/verify-line.sh [--skip-health] [--non-strict]

Checks LINE env, adapter syntax, local health, and public health.

Options:
  --skip-health  Check env and adapter only. Useful during installation before
                 the Hermes gateway/container has been restarted.
  --non-strict   Always exit 0 after printing failures.
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

FAILED=0
fail() {
  FAILED=1
}

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
if [ -n "$LINE_CHANNEL_ACCESS_TOKEN_VALUE" ]; then echo "LINE_CHANNEL_ACCESS_TOKEN=SET"; else echo "LINE_CHANNEL_ACCESS_TOKEN=MISSING"; fail; fi
if [ -n "$LINE_CHANNEL_SECRET_VALUE" ]; then echo "LINE_CHANNEL_SECRET=SET"; else echo "LINE_CHANNEL_SECRET=MISSING"; fail; fi
if [ -n "$LINE_PUBLIC_URL_VALUE" ]; then echo "LINE_PUBLIC_URL=$LINE_PUBLIC_URL_VALUE"; else echo "LINE_PUBLIC_URL=MISSING"; fail; fi
echo "LINE_PORT=$LINE_PORT_VALUE"

echo
if [ -f "$ADAPTER" ]; then
  echo "== Adapter syntax =="
  if PYTHONPYCACHEPREFIX=/tmp/hermes_pycache python3 -m py_compile "$ADAPTER"; then
    echo "adapter_py_compile=OK"
  else
    echo "adapter_py_compile=FAILED"
    fail
  fi
else
  echo "adapter_py_compile=FAILED (not found: $ADAPTER)"
  fail
fi

echo
if [ "$SKIP_HEALTH" = "1" ]; then
  echo "health=SKIPPED (--skip-health)"
  if [ "$FAILED" = "0" ] || [ "$NON_STRICT" = "1" ]; then exit 0; fi
  exit 1
fi

LOCAL_HEALTH="http://127.0.0.1:${LINE_PORT_VALUE}/line/webhook/health"
echo "== Local health =="
echo "$LOCAL_HEALTH"
if curl -fsS --max-time 5 "$LOCAL_HEALTH"; then
  echo
  echo "local_health=OK"
else
  echo
  echo "local_health=FAILED"
  fail
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
    fail
  fi
  echo
  echo "LINE webhook URL: $PUBLIC_BASE/line/webhook"
fi

if [ "$FAILED" = "0" ] || [ "$NON_STRICT" = "1" ]; then
  exit 0
fi
exit 1
