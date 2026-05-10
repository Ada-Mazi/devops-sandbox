#!/bin/bash

ENV_ID=""
MODE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env) ENV_ID="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [ -z "$ENV_ID" ] || [ -z "$MODE" ]; then
    echo "Usage: simulate_outage.sh --env ENV_ID --mode [crash|pause|network|recover|stress]"
    exit 1
fi

# Guard: never run against platform containers
if [[ "$ENV_ID" == "sandbox-nginx" ]] || [[ "$ENV_ID" == "sandbox-daemon" ]] || [[ "$ENV_ID" == "sandbox-api" ]]; then
    echo "ERROR: Cannot simulate outage against platform containers!"
    exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="${BASE_DIR}/envs/${ENV_ID}.json"

if [ ! -f "$STATE_FILE" ]; then
    echo "ERROR: Environment $ENV_ID not found"
    exit 1
fi

NETWORK=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('network',''))" 2>/dev/null)

echo "[simulate_outage] Running mode=$MODE on env=$ENV_ID"

case "$MODE" in
    crash)
        docker kill "$ENV_ID" 2>/dev/null
        echo "[simulate_outage] Container $ENV_ID killed"
        ;;
    pause)
        docker pause "$ENV_ID" 2>/dev/null
        echo "[simulate_outage] Container $ENV_ID paused"
        ;;
    network)
        docker network disconnect "$NETWORK" "$ENV_ID" 2>/dev/null
        echo "[simulate_outage] Container $ENV_ID disconnected from network"
        ;;
    recover)
        docker unpause "$ENV_ID" 2>/dev/null || true
        docker start "$ENV_ID" 2>/dev/null || true
        docker network connect "$NETWORK" "$ENV_ID" 2>/dev/null || true
        docker network connect sandbox-platform "$ENV_ID" 2>/dev/null || true
        echo "[simulate_outage] Container $ENV_ID recovered"
        ;;
    stress)
        docker exec "$ENV_ID" sh -c "apt-get update > /dev/null 2>&1; apt-get install -y stress-ng > /dev/null 2>&1; stress-ng --cpu 2 --timeout 30 &" 2>/dev/null || true
        echo "[simulate_outage] Stress test started on $ENV_ID"
        ;;
    *)
        echo "Unknown mode: $MODE"
        exit 1
        ;;
esac
