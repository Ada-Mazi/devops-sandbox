#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="${BASE_DIR}/logs/cleanup.log"

mkdir -p "${BASE_DIR}/logs"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Cleanup daemon started" >> "$LOG_FILE"

while true; do
    NOW=$(date -u +%s)
    for STATE_FILE in "${BASE_DIR}/envs/"*.json; do
        [ -f "$STATE_FILE" ] || continue
        ENV_ID=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d['id'])" 2>/dev/null)
        CREATED_AT=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d['created_at'])" 2>/dev/null)
        TTL=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d['ttl'])" 2>/dev/null)
        EXPIRES_AT=$(( CREATED_AT + TTL ))
        if [ "$NOW" -gt "$EXPIRES_AT" ]; then
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] TTL expired for $ENV_ID - destroying" >> "$LOG_FILE"
            bash "${BASE_DIR}/platform/destroy_env.sh" "$ENV_ID" >> "$LOG_FILE" 2>&1
        fi
    done
    sleep 60
done
