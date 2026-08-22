#!/usr/bin/env bash
set -e

BACKUP_DIR="/var/backups/predictoraai"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
FILE="${BACKUP_DIR}/pg-backup-${TIMESTAMP}.sql"

PGUSER="predictora"
PGDB="predictora"
PGHOST="localhost"

echo "[BACKUP] Dumping PostgreSQL to ${FILE}..."
PGUSER="$PGUSER" PGHOST="$PGHOST" pg_dump "$PGDB" > "$FILE"
echo "[BACKUP] Done."
