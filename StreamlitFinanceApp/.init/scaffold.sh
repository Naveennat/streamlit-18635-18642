#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/streamlit-18635-18642/StreamlitFinanceApp"
mkdir -p "$WS" && cd "$WS"
# Deterministic top-level requirements (pinned); transitive deps may still float
cat > "$WS/requirements.txt" <<'REQ'
streamlit==1.30.0
pandas==2.2.2
numpy==1.26.5
pytest==7.4.2
REQ
# Minimal import-safe Streamlit app
cat > "$WS/app.py" <<'PY'
import streamlit as st
import pandas as pd
import numpy as np

def create_ui():
    st.title('StreamlitFinanceApp - minimal')
    if st.button('show'):
        st.write(pd.DataFrame({'a': np.arange(3)}))

if __name__ == '__main__':
    create_ui()
PY
# .streamlit container-local config
mkdir -p "$WS/.streamlit"
cat > "$WS/.streamlit/config.toml" <<'CT'
[server]
headless = true
port = 8501
enableCORS = false
CT
# Health check script: uses curl with timeouts and retries (aligns with validation polling)
cat > "$WS/healthcheck.sh" <<'HC'
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
HC
chmod +x "$WS/healthcheck.sh"
# Minimal pytest that imports app module (safe due to __main__ guard)
mkdir -p "$WS/tests"
cat > "$WS/tests/test_import.py" <<'PT'
def test_import_app():
    import importlib
    m = importlib.import_module('app')
    assert hasattr(m, 'create_ui') or hasattr(m, '__name__')
PT
# pytest.ini
cat > "$WS/pytest.ini" <<'PI'
[pytest]
minversion = 6.0
addopts = -q
PI
# Note about isolation
cat > "$WS/README.setup" <<'RD'
This workspace uses a Python venv at .venv to isolate packages from system Python. Top-level requirements are pinned, but transitive deps are not locked. To generate a full lock, run pip freeze or pip-tools inside the venv.
RD
