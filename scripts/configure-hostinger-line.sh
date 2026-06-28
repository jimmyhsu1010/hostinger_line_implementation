#!/usr/bin/env bash
set -euo pipefail

find_hermes() {
  if command -v hermes >/dev/null 2>&1; then command -v hermes; return 0; fi
  for p in /opt/hermes/bin/hermes /opt/hermes/.venv/bin/hermes /usr/local/bin/hermes; do
    if [ -x "$p" ]; then echo "$p"; return 0; fi
  done
  return 1
}

HERMES_BIN="${HERMES_BIN:-$(find_hermes || true)}"
if [ -z "$HERMES_BIN" ]; then
  echo "ERROR: hermes command not found. Run this inside the Hermes container." >&2
  exit 1
fi

echo "Using Hermes: $HERMES_BIN"

do_set() {
  local key="$1" value="$2"
  echo "config set $key = $value"
  "$HERMES_BIN" config set "$key" "$value" >/dev/null
}

# Safe defaults for Hostinger + LINE deployments.
do_set timezone Asia/Taipei
do_set security.redact_secrets true
do_set compression.enabled true
do_set compression.codex_gpt55_autoraise false
do_set agent.reasoning_effort medium
do_set agent.gateway_timeout 1800
do_set agent.gateway_timeout_warning 900

# STT is optional; enable only when explicitly requested.
if [ "${WITH_STT:-0}" = "1" ] || [ "${1:-}" = "--with-stt" ]; then
  do_set stt.enabled true
  do_set stt.provider local
  echo "STT enabled. Make sure local STT dependencies or HERMES_LOCAL_STT_COMMAND are configured."
else
  echo "STT not changed. Re-run with WITH_STT=1 or --with-stt if voice transcription is required."
fi

echo "OK: config updated. Restart the Hermes container/gateway for changes to take effect."
