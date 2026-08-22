#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/deploy/predictoraai"
COMPOSE_FILE="docker-compose.prod.yml"

cd "$PROJECT_DIR"

echo "[core] building internal images..."
docker compose -f "$COMPOSE_FILE" build \
  predictora-backend \
  predictora-billing \
  guardian \
  predictoraai-stripe-webhook \
  predictoraai-frontend \
  predictoraai-admin-frontend \
  predictoraai-revenue-exporter

echo "[core] bringing stack up..."
docker compose -f "$COMPOSE_FILE" up -d

echo "[core] status:"
docker compose -f "$COMPOSE_FILE" ps
