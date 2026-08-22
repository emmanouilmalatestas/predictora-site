#!/usr/bin/env bash
set -euo pipefail

TS=$(date +%Y%m%d-%H%M%S)
BACKUP="/tmp/pg_backup_$TS.sql.gz"

echo "[*] Dumping Postgres…"
docker exec predictoraai-db pg_dump -U postgres -d postgres | gzip > "$BACKUP"

echo "[*] Uploading to S3…"
aws s3 cp "$BACKUP" s3://YOUR_BUCKET_NAME/db_backups/

echo "[✓] Backup completed: $BACKUP"
