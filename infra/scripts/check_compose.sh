#!/usr/bin/env bash
set -euo pipefail

cd /home/deploy/predictoraai

echo "[*] Validating docker-compose.yml…"
docker compose config > /dev/null

echo "[✓] Compose is valid."
