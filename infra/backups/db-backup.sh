#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_DIR="/var/backups/predictoraai"
FILENAME="${BACKUP_DIR}/predictoraai-${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

docker exec predictoraai-db pg_dump -U postgres predictoraai | gzip > "${FILENAME}"

find "${BACKUP_DIR}" -type f -mtime +7 -delete
