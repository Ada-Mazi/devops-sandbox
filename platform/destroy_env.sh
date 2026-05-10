#!/bin/bash
set -e

ENV_ID="$1"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="${BASE_DIR}/envs/${ENV_ID}.json"
LOG_DIR="${BASE_DIR}/logs/${ENV_ID}"
ARCHIVE_DIR="${BASE_DIR}/logs/archived/${ENV_ID}"
NGINX_CONF="${BASE_DIR}/nginx/conf.d/${ENV_ID}.conf"

if [ ! -f "$STATE_FILE" ]; then
    echo "[destroy_env] ERROR: Environment $ENV_ID not found"
    exit 1
fi

echo "[destroy_env] Destroying environment: $ENV_ID"

# Kill log shipping process
if [ -f "${LOG_DIR}/log_pid" ]; then
    LOG_PID=$(cat "${LOG_DIR}/log_pid")
    kill "$LOG_PID" 2>/dev/null || true
    rm -f "${LOG_DIR}/log_pid"
fi

# Stop and remove container
docker stop "$ENV_ID" 2>/dev/null || true
docker rm "$ENV_ID" 2>/dev/null || true

# Remove Docker network
NETWORK=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('network',''))" 2>/dev/null || echo "${ENV_ID}-net")
docker network rm "$NETWORK" 2>/dev/null || true

# Remove Nginx config and reload
rm -f "$NGINX_CONF"
docker exec sandbox-nginx nginx -s reload 2>/dev/null || true

# Archive logs
mkdir -p "$ARCHIVE_DIR"
cp -r "${LOG_DIR}/." "$ARCHIVE_DIR/" 2>/dev/null || true
rm -rf "$LOG_DIR"

# Delete state file
rm -f "$STATE_FILE"

echo "[destroy_env] Environment $ENV_ID destroyed and logs archived."
