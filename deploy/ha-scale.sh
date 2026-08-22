#!/usr/bin/env bash
set -e

COMPOSE_FILE="../docker-compose.prod.yml"

docker compose -f "$COMPOSE_FILE" up -d \
  --scale predictora-backend=2 \
  --scale predictora-billing=2 \
  --scale event-ingestor=2 \
  --scale predictoraai-stripe-webhook=2 \
  --scale guardian=2
