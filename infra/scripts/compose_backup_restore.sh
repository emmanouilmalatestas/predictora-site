#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/deploy/predictoraai"
COMPOSE="$ROOT/docker-compose.yml"
BACKUP_DIR="$ROOT/infra/backups"

mkdir -p "$BACKUP_DIR"

case "${1:-}" in
  backup)
    TS="$(date +%Y%m%d-%H%M%S)"
    FILE="$BACKUP_DIR/docker-compose.yml.$TS"
    cp "$COMPOSE" "$FILE"
    echo "[✓] Backup created: $FILE"
    ;;
  restore)
    LAST="$(ls -1 "$BACKUP_DIR"/docker-compose.yml.* 2>/dev/null | tail -n 1 || true)"
    if [ -z "$LAST" ]; then
      echo "[!] No backups found."
      exit 1
    fi
    cp "$LAST" "$COMPOSE"
    echo "[✓] Restored from: $LAST"
    ;;
  *)
    echo "Usage: $0 backup|restore"
    exit 1
    ;;
esac
