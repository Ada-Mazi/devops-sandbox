#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

while true; do
    for STATE_FILE in "${BASE_DIR}/envs/"*.json; do
        [ -f "$STATE_FILE" ] || continue
        ENV_ID=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d['id'])" 2>/dev/null)
        PORT=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d['port'])" 2>/dev/null)
        LOG_FILE="${BASE_DIR}/logs/${ENV_ID}/health.log"
        mkdir -p "${BASE_DIR}/logs/${ENV_ID}"
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        START=$(date +%s%N)
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:${PORT}/health" 2>/dev/null || echo "000")
        END=$(date +%s%N)
        LATENCY=$(( (END - START) / 1000000 ))
        echo "${TIMESTAMP} status=${HTTP_STATUS} latency=${LATENCY}ms" >> "$LOG_FILE"

        # Check for 3 consecutive failures
        FAILURES=$(tail -3 "$LOG_FILE" 2>/dev/null | grep -c "status=000\|status=5" || true)
        if [ "$FAILURES" -ge 3 ]; then
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WARNING: $ENV_ID is DEGRADED" | tee -a "$LOG_FILE"
            TEMP="${STATE_FILE}.tmp"
            python3 -c "
import json
with open('${STATE_FILE}') as f:
    d = json.load(f)
d['status'] = 'degraded'
with open('${TEMP}', 'w') as f:
    json.dump(d, f, indent=2)
"
            mv "$TEMP" "$STATE_FILE"
        fi
    done
    sleep 30
done
