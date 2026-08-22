#!/usr/bin/env bash
set -euo pipefail

cd /home/deploy/predictoraai

echo "[billing] rebuilding image..."
docker compose -f docker-compose.prod.yml build --no-cache predictora-billing

echo "[billing] restarting container..."
docker compose -f docker-compose.prod.yml up -d predictora-billing

echo "[billing] tailing logs..."
docker logs -f --tail=100 predictora-billing
