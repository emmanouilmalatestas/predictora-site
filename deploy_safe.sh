#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/deploy/predictoraai"
COMPOSE="$ROOT/docker-compose.yml"
BACKUP_DIR="$ROOT/infra/backups"

mkdir -p "$BACKUP_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/docker-compose.yml.$TS"

echo "[*] Backing up docker-compose.yml → $BACKUP_FILE"
cp "$COMPOSE" "$BACKUP_FILE"

echo "[*] Running compose validation module…"
$ROOT/infra/scripts/check_compose.sh

echo "[*] YAML OK. Proceeding with deploy…"
cd "$ROOT"
docker compose down
docker compose up -d

echo "[✓] Safe deploy completed."
