#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/streamlit-18635-18642/StreamlitFinanceApp"
mkdir -p "$WS" && cd "$WS"
# create venv if missing
if [ ! -d ".venv" ]; then python3 -m venv ".venv"; fi
PYTHON="$WS/.venv/bin/python"
# requirements (conservative compatible ranges)
if [ ! -f requirements.txt ]; then cat > requirements.txt <<'REQ'
streamlit>=1.29,<2.0
pandas>=2.1,<3.0
numpy>=1.26,<2.0
REQ
fi
if [ ! -f app.py ]; then cat > app.py <<'PY'
import streamlit as st
st.title('Streamlit Finance App - Dev Scaffold')
st.write('This is a scaffold. Replace with your app code.')
PY
fi
if [ ! -f README.md ]; then cat > README.md <<MD
# StreamlitFinanceApp
Scaffolded minimal Streamlit app.
Activate venv: source .venv/bin/activate
Run headless for CI/dev: STREAMLIT_SERVER_HEADLESS=1 ${PYTHON} -m streamlit run app.py --server.runOnSave=false --server.port=8501
MD
fi
