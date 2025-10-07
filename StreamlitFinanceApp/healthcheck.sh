#!/usr/bin/env bash
set -euo pipefail
PORT=${1:-${STREAMLIT_SERVER_PORT:-8501}}
ATTEMPTS=${2:-10}
SLEEP=${3:-3}
TIMEOUT_CONNECT=1
TIMEOUT_TOTAL=3
i=0
while [ $i -lt $ATTEMPTS ]; do
  if curl --connect-timeout $TIMEOUT_CONNECT --max-time $TIMEOUT_TOTAL -sSf "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    exit 0
  fi
  i=$((i+1))
  sleep $SLEEP
done
exit 1
