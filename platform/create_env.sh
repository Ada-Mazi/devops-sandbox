#!/bin/bash
set -e

NAME=${1:-"myenv"}
TTL=${2:-1800}
ENV_ID="env-$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 8)"
PORT=$(shuf -i 10000-19999 -n 1)
CREATED_AT=$(date -u +%s)
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NETWORK="${ENV_ID}-net"
STATE_FILE="${BASE_DIR}/envs/${ENV_ID}.json"
LOG_DIR="${BASE_DIR}/logs/${ENV_ID}"
NGINX_CONF="${BASE_DIR}/nginx/conf.d/${ENV_ID}.conf"

echo "[create_env] Creating environment: $ENV_ID (name=$NAME, ttl=${TTL}s, port=$PORT)"

mkdir -p "$LOG_DIR"

# Create Docker network
docker network create "$NETWORK" > /dev/null 2>&1

# Start app container
docker run -d \
  --name "$ENV_ID" \
  --network "$NETWORK" \
  --label "sandbox.env=$ENV_ID" \
  --label "sandbox.name=$NAME" \
  -e ENV_ID="$ENV_ID" \
  -e ENV_NAME="$NAME" \
  -e PORT=5000 \
  -p "${PORT}:5000" \
  sandbox-app:latest > /dev/null 2>&1

# Connect to sandbox-platform network for nginx access
docker network connect sandbox-platform "$ENV_ID" 2>/dev/null || true

# Write Nginx config
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen 80;
    server_name ${ENV_ID}.sandbox.local;

    location / {
        proxy_pass http://${ENV_ID}:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Env-ID ${ENV_ID};
    }
}
NGINXEOF

# Reload Nginx
docker exec sandbox-nginx nginx -s reload 2>/dev/null || true

# Write state file atomically
TEMP_FILE="${STATE_FILE}.tmp"
cat > "$TEMP_FILE" << JSONEOF
{
  "id": "${ENV_ID}",
  "name": "${NAME}",
  "created_at": ${CREATED_AT},
  "ttl": ${TTL},
  "port": ${PORT},
  "status": "running",
  "network": "${NETWORK}"
}
JSONEOF
mv "$TEMP_FILE" "$STATE_FILE"

# Start log shipping
docker logs -f "$ENV_ID" >> "${LOG_DIR}/app.log" 2>&1 &
echo $! > "${LOG_DIR}/log_pid"

echo "[create_env] Environment ready!"
echo "  ENV_ID  : $ENV_ID"
echo "  URL     : http://34.46.53.225:${PORT}"
echo "  TTL     : ${TTL}s ($(( TTL / 60 )) minutes)"
echo "  State   : $STATE_FILE"
