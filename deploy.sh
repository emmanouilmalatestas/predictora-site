#!/bin/bash
set -euo pipefail

COMPOSE_FILE="docker-compose.prod.yml"
LOG_FILE="deploy.log"
BACKEND_CONTAINER="predictora-backend"
HEALTH_URL="https://api.predictoraai.com/health"

echo "=== Deploy started at $(date) ===" | tee -a "$LOG_FILE"

echo "=== [STEP 1] Running pre-deploy modules ===" | tee -a "$LOG_FILE"
./run_modules.sh | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

echo "=== [STEP 2] Building images ===" | tee -a "$LOG_FILE"
docker compose -f "$COMPOSE_FILE" build | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

echo "=== [STEP 3] Deploying stack (recreate backend + traefik) ===" | tee -a "$LOG_FILE"
docker compose -f "$COMPOSE_FILE" up -d --force-recreate traefik "$BACKEND_CONTAINER" | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

echo "=== [STEP 4] Waiting for backend HTTP health ==="

BACKEND_NAME="predictora-backend"
MAX_WAIT=120
INTERVAL=5
elapsed=0

while [ "$elapsed" -lt "$MAX_WAIT" ]; do
  if ! docker ps --format '{{.Names}}' | grep -q "^${BACKEND_NAME}$"; then
    echo "[HEALTH] ERROR: ${BACKEND_NAME} is not running"
    exit 1
  fi

  if curl -sf http://localhost:8000/health >/dev/null 2>&1; then
    echo "[HEALTH] Backend HTTP health OK (elapsed=${elapsed}s)"
    break
  else
    echo "[HEALTH] Backend HTTP health not ready (elapsed=${elapsed}s)"
  fi

  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

if [ "$elapsed" -ge "$MAX_WAIT" ]; then
  echo "[HEALTH] ERROR: backend did not become healthy in time"
  exit 1
fi

echo "=== [STEP 5] HTTP health check on ${HEALTH_URL} ===" | tee -a "$LOG_FILE"

MAX_HTTP_RETRIES=5
RETRY_DELAY=3
ATTEMPT=1
HTTP_OK=false

while [ "$ATTEMPT" -le "$MAX_HTTP_RETRIES" ]; do
  echo "[HEALTH] HTTP attempt ${ATTEMPT}/${MAX_HTTP_RETRIES}" | tee -a "$LOG_FILE"
  RESPONSE=$(curl -sk "$HEALTH_URL" || true)

  if echo "$RESPONSE" | grep -qi "ok"; then
    echo "[HEALTH] OK: /health responded with 'ok'" | tee -a "$LOG_FILE"
    HTTP_OK=true
    break
  else
    echo "[HEALTH] WARNING: /health response not 'ok' (response='${RESPONSE}')" | tee -a "$LOG_FILE"
  fi

  ATTEMPT=$((ATTEMPT + 1))
  sleep "$RETRY_DELAY"
done

if [ "$HTTP_OK" = false ]; then
  echo "[HEALTH] ERROR: /health did not respond with 'ok' after ${MAX_HTTP_RETRIES} attempts" | tee -a "$LOG_FILE"
  exit 1
fi

echo "=== Deploy completed successfully at $(date) ===" | tee -a "$LOG_FILE"
