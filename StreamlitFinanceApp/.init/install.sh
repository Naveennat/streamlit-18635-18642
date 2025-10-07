#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/streamlit-18635-18642/StreamlitFinanceApp"
cd "$WS"
# ensure venv exists
if [ ! -d ".venv" ]; then
echo "ERROR: venv .venv missing; run scaffold step" >&2; exit 2; fi
PYTHON="$WS/.venv/bin/python"
# validate venv python prefix
PFX_REAL=$(readlink -f "$WS/.venv" 2>/dev/null || echo "$WS/.venv")
if [ "$(readlink -f "$($PYTHON -c 'import sys; print(sys.prefix)')")" != "$PFX_REAL" ]; then
  echo "ERROR: venv python sys.prefix does not match $WS/.venv" >&2; exit 2
fi
if [ ! -f requirements.txt ]; then echo "ERROR: requirements.txt missing in workspace" >&2; exit 2; fi
# upgrade pip/setuptools/wheel quietly using venv python
"$PYTHON" -m pip install --upgrade pip setuptools wheel --disable-pip-version-check -q
# attempt install; on failure install python3-dev and retry once
set +e
"$PYTHON" -m pip install -r requirements.txt --disable-pip-version-check -q
RC=$?
set -e
if [ $RC -ne 0 ]; then
  sudo apt-get update -q >/dev/null && sudo apt-get install -yq python3-dev >/dev/null
  set +e
  "$PYTHON" -m pip install -r requirements.txt --disable-pip-version-check -q
  RC2=$?
  set -e
  if [ $RC2 -ne 0 ]; then echo "ERROR: pip install failed after installing python3-dev" >&2; exit 3; fi
fi
# quick import verification for key libs
"$PYTHON" - <<'PY'
import sys
try:
    import streamlit, pandas, numpy
    print('imports_ok')
except Exception as e:
    print('ERROR: import failed:', e, file=sys.stderr)
    sys.exit(4)
PY
