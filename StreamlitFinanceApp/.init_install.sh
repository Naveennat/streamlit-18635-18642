#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/streamlit-18635-18642/StreamlitFinanceApp"
mkdir -p "$WS" "$WS/logs" && cd "$WS"
# Ensure system venv support
if ! python3 -m venv --help >/dev/null 2>&1; then
  sudo apt-get update -q >/dev/null && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q python3-venv >/dev/null
fi
# Create venv idempotently
if [ ! -d "$WS/.venv" ]; then
  python3 -m venv "$WS/.venv"
fi
VENV_PY="$WS/.venv/bin/python"
VENV_PIP="$WS/.venv/bin/pip"
# Validate venv python exists
if [ ! -x "$VENV_PY" ]; then
  echo "error: venv python not found at $VENV_PY" >&2
  exit 5
fi
# Upgrade pip inside venv (use absolute python to avoid PATH assumptions)
mkdir -p "$WS/logs"
"$VENV_PY" -m pip install --upgrade pip >"$WS/logs/pip_upgrade_env.log" 2>&1 || { cat "$WS/logs/pip_upgrade_env.log" >&2; exit 10; }
# Export headless for current session for immediate use
export STREAMLIT_SERVER_HEADLESS=true
# Optional persistent global export (controlled by env var); default off to avoid altering container state
if [ "${STREAMLIT_PERSIST_ENV:-false}" = "true" ]; then
  PROFILE_FILE=/etc/profile.d/streamlit_env.sh
  TMPFILE=$(mktemp)
  cat > "$TMPFILE" <<'EOF'
# Streamlit automation defaults (created by setup script)
export STREAMLIT_SERVER_HEADLESS=true
# To remove: sudo rm -f /etc/profile.d/streamlit_env.sh
EOF
  sudo mv "$TMPFILE" "$PROFILE_FILE" && sudo chmod 644 "$PROFILE_FILE" || { echo "failed to write $PROFILE_FILE with sudo" >&2; rm -f "$TMPFILE" || true; exit 11; }
fi
# Verify venv pip is usable
"$VENV_PY" -m pip -V >/dev/null 2>&1 || { echo "venv pip unusable" >&2; exit 12; }
