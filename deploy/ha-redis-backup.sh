#!/usr/bin/env bash
set -e

BACKUP_DIR="/var/backups/predictoraai"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
FILE="${BACKUP_DIR}/redis-backup-${TIMESTAMP}.rdb"

REDIS_CLI="redis-cli"

echo "[BACKUP] Forcing Redis SAVE..."
$REDIS_CLI SAVE

SRC="/var/lib/redis/dump.rdb"  # άλλαξέ το αν είναι αλλού
cp "$SRC" "$FILE"

echo "[BACKUP] Redis backup saved to ${FILE}."
