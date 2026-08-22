#!/usr/bin/env bash
set -e

CRITICAL_SERVICES=("backend" "webhook" "billing" "event_ingestor" "guardian")
COMPOSE_FILE="../docker-compose.prod.yml"

check_service() {
  local name="$1"
  local count
  count=$(docker ps --filter "name=${name}" --filter "status=running" -q | wc -l)

  if [ "$count" -lt 1 ]; then
    echo "[HEAL] ${name} down, restarting..."
    docker compose -f "$COMPOSE_FILE" up -d "$name"
  fi
}

while true; do
  for svc in "${CRITICAL_SERVICES[@]}"; do
    check_service "$svc"
  done
  sleep 15
done
