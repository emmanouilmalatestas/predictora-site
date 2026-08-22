#!/usr/bin/env bash
set -e

COMPOSE_FILE="../docker-compose.prod.yml"

echo "[DEPLOY] Bringing up full stack..."
docker compose -f "$COMPOSE_FILE" up -d

echo "[DEPLOY] Scaling critical services..."
./ha-scale.sh

echo "[DEPLOY] Starting health watcher (background)..."
nohup "$(dirname "$0")"/ha-health-watch.sh >"$(dirname "$0")"/../logs/ha-health-watch.log 2>&1 &

echo "[DEPLOY] HA stack active."
