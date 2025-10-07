#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/streamlit-18635-18642/StreamlitFinanceApp"
cd "$WS"
VENV_PY="$WS/.venv/bin/python"
VENV_PIP="$WS/.venv/bin/pip"
if [ ! -x "$VENV_PY" ]; then echo "venv missing, run env-01" >&2; exit 6; fi
mkdir -p "$WS/logs"
# Ensure pip/tools are recent
"$VENV_PY" -m pip install --upgrade pip setuptools wheel >"$WS/logs/pip_upgrade.log" 2>&1 || { cat "$WS/logs/pip_upgrade.log" >&2; exit 13; }
# Try install with limited retries
attempts=0
max=3
backoff=2
install_ok=0
while [ $attempts -lt $max ]; do
  if "$VENV_PY" -m pip install --prefer-binary --no-cache-dir -r requirements.txt >"$WS/logs/pip_install.log" 2>&1; then
    install_ok=1 && break
  fi
  attempts=$((attempts+1))
  sleep $((backoff * attempts))
done
if [ $install_ok -eq 0 ]; then
  # Check for numpy incompatibility
  if grep -E "No matching distribution found for numpy==|Could not find a version that satisfies the requirement numpy==" "$WS/logs/pip_install.log" >/dev/null 2>&1; then
    cp requirements.txt requirements.txt.bak
    # Try to pick newest available numpy via pip index
    CAND=$("$VENV_PY" - <<'PY'
import sys,subprocess
req='numpy'
try:
    out = subprocess.check_output([sys.executable,'-m','pip','index','versions',req], stderr=subprocess.STDOUT, text=True)
    for line in out.splitlines():
        if 'Available versions:' in line:
            verstr=line.split(':',1)[1].strip()
            versions=[v.strip() for v in verstr.split(',') if v.strip()]
            if versions:
                print(versions[0])
                sys.exit(0)
except Exception:
    pass
sys.exit(1)
PY
)
    if [ -n "${CAND:-}" ]; then
      # Replace only a top-level numpy line (conservative edit). If sed fails, restore backup.
      sed -E "s/^numpy([<=>].*)?$/numpy==${CAND}/" requirements.txt.bak > requirements.txt || cp requirements.txt.bak requirements.txt
      echo "Updated requirements.txt with numpy==${CAND}" >"$WS/logs/requirements_adjust.log"
      if "$VENV_PY" -m pip install --prefer-binary --no-cache-dir -r requirements.txt >"$WS/logs/pip_install_retry.log" 2>&1; then
        install_ok=1
      else
        echo "pip install still failed after numpy fallback; see logs" >&2
        tail -n 200 "$WS/logs/pip_install_retry.log" >&2 || true
        exit 14
      fi
    else
      echo "Could not determine a compatible numpy version automatically; check $WS/logs/pip_install.log" >&2
      tail -n 200 "$WS/logs/pip_install.log" >&2 || true
      exit 14
    fi
  else
    echo "pip install failed for reasons other than pinned numpy incompatibility; see logs" >&2
    tail -n 200 "$WS/logs/pip_install.log" >&2 || true
    exit 14
  fi
fi
# Validation imports
"$VENV_PY" - <<'PY'
import sys
try:
    import streamlit as s
    import pytest as p
    import numpy as n
    import pandas as pd
    print('python', sys.version.split()[0])
    print('streamlit', getattr(s,'__version__', 'unknown'))
    print('pytest', getattr(p,'__version__', 'unknown'))
    print('numpy', getattr(n,'__version__', 'unknown'))
    print('pandas', getattr(pd,'__version__', 'unknown'))
except Exception as e:
    print('validation import failed:', e, file=sys.stderr)
    raise
PY
