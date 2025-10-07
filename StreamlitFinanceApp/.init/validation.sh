#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/streamlit-18635-18642/StreamlitFinanceApp"
cd "$WS"
PYTHON="$WS/.venv/bin/python"
# verify imports
"$PYTHON" - <<'PY'
import sys
try:
    import streamlit, pandas, numpy
    print('imports_ok')
except Exception as e:
    print('ERROR: imports failed:', e, file=sys.stderr)
    sys.exit(2)
PY
PORT=8501
TIMEOUT=${TIMEOUT:-90}
OUT=$(mktemp)
# port check: prefer ss, fallback to netstat
if command -v ss >/dev/null 2>&1; then
  if ss -ltn '( sport = :'$PORT' )' | grep -q LISTEN; then echo "ERROR: port ${PORT} appears in use" >&2; ss -ltnp | grep ":${PORT}" || true; exit 4; fi
else
  if command -v netstat >/dev/null 2>&1 && netstat -ltn | awk '{print $4}' | grep -q ":${PORT}$"; then echo "ERROR: port ${PORT} appears in use" >&2; netstat -ltnp | grep ":${PORT}" || true; exit 4; fi
fi
# start streamlit via venv python -u -m streamlit, redirect logs
export STREAMLIT_SERVER_HEADLESS=1
TS=$(date +%s)
"$PYTHON" -u -m streamlit run app.py --server.runOnSave=false --server.port=${PORT} >"$OUT" 2>&1 &
START_WRAPPER_PID=$!
# detect actual streamlit PID: prefer pgrep matching the venv python invocation and streamlit module
sleep 0.5
ST_PID=""
for i in $(seq 1 8); do
  ST_PID=$(pgrep -f "${WS}/.venv.*python.*-m streamlit|python.*-m streamlit" || true)
  if [ -n "$ST_PID" ]; then break; fi
  sleep 0.5
 done
# if pgrep returned multiple PIDs, pick the newest by start time
if [ -n "$ST_PID" ]; then
  BEST_PID=""
  for PID in $ST_PID; do
    if [ -z "$BEST_PID" ]; then BEST_PID=$PID; continue; fi
    if [ "$(stat -c %Y /proc/$PID 2>/dev/null || echo 0)" -gt "$(stat -c %Y /proc/$BEST_PID 2>/dev/null || echo 0)" ]; then BEST_PID=$PID; fi
  done
  ST_PID=$BEST_PID
fi
# fallback: parse the log for 'Local URL' or similar to infer server started
if [ -z "$ST_PID" ]; then
  for i in $(seq 1 $TIMEOUT); do
    if grep -qiE "local url|network url|running on" "$OUT" >/dev/null 2>&1; then break; fi
    sleep 1
  done
  ST_PID=$(pgrep -f "streamlit" || true)
fi
# wait for server to accept connections
SECS=0
SUCCESS=1
while [ $SECS -lt "$TIMEOUT" ]; do
  if curl -sS --max-time 2 http://127.0.0.1:${PORT}/ >/dev/null 2>&1; then SUCCESS=0 && break; fi
  sleep 1
  SECS=$((SECS+1))
 done
if [ $SUCCESS -ne 0 ]; then
  echo "Validation FAILED: streamlit did not respond within ${TIMEOUT}s. Logs:" >&2
  sed -n '1,200p' "$OUT" >&2 || true
  if [ -n "$ST_PID" ]; then
    PGID=$(ps -o pgid= -p "$ST_PID" 2>/dev/null | tr -d ' ' || true)
    [ -n "$PGID" ] && kill -- -"$PGID" 2>/dev/null || true
    pkill -P "$ST_PID" 2>/dev/null || true
    kill "$ST_PID" 2>/dev/null || true
  else
    kill "$START_WRAPPER_PID" 2>/dev/null || true
  fi
  wait 2>/dev/null || true
  rm -f "$OUT"
  exit 5
fi
HTTP_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:${PORT}/)
echo "Validation OK: streamlit responded in ${SECS}s; HTTP_STATUS=${HTTP_STATUS}"
echo "--- tail of server log ---"
tail -n 50 "$OUT" || true
# clean termination: prefer PGID if we have ST_PID
if [ -n "$ST_PID" ]; then
  PGID=$(ps -o pgid= -p "$ST_PID" 2>/dev/null | tr -d ' ' || true)
  if [ -n "$PGID" ]; then kill -- -"$PGID" 2>/dev/null || true; fi
  pkill -P "$ST_PID" 2>/dev/null || true
  kill "$ST_PID" 2>/dev/null || true
else
  kill "$START_WRAPPER_PID" 2>/dev/null || true
fi
wait 2>/dev/null || true
rm -f "$OUT"
