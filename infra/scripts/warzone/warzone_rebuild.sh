#!/bin/bash
set -e

BASE="/home/deploy/predictoraai"
BACKUP="$BASE/_warzone_backup_$(date +%Y%m%d_%H%M%S)"

echo "=== WARZONE 9000 REPO REBUILD (DRY RUN) ==="
echo "[*] BASE:   $BASE"
echo "[*] BACKUP: $BACKUP"

echo
echo "[1] Would create backup directory:"
echo "    mkdir -p \"$BACKUP\""
echo "    cp -r \"$BASE/admin-frontend\" \"$BACKUP/\""
echo "    cp -r \"$BASE/frontend\" \"$BACKUP/\""
echo "    cp -r \"$BASE/backend\" \"$BACKUP/\""
echo "    cp -r \"$BASE/docker-compose.yml\" \"$BACKUP/\""

echo
echo "[2] Would create new structure:"
echo "    mkdir -p \"$BASE/apps/admin\""
echo "    mkdir -p \"$BASE/apps/client\""
echo "    mkdir -p \"$BASE/services/api\""
echo "    mkdir -p \"$BASE/services/event-bus\""
echo "    mkdir -p \"$BASE/services/metering\""
echo "    mkdir -p \"$BASE/services/workers\""
echo "    mkdir -p \"$BASE/infra/docker\""
echo "    mkdir -p \"$BASE/infra/traefik\""
echo "    mkdir -p \"$BASE/infra/scripts\""
echo "    mkdir -p \"$BASE/shared\""

echo
echo "[3] Would move frontends:"
echo "    mv \"$BASE/admin-frontend\"/* \"$BASE/apps/admin/\""
echo "    mv \"$BASE/frontend\"/* \"$BASE/apps/client/\""

echo
echo "[4] Would move backend core:"
echo "    mv \"$BASE/backend/app\" \"$BASE/services/api/\""
echo "    mv \"$BASE/backend/src\" \"$BASE/services/api/\""
echo "    mv \"$BASE/backend/models\" \"$BASE/services/api/\" || true"
echo "    mv \"$BASE/backend/services\" \"$BASE/services/api/\" || true"
echo "    mv \"$BASE/backend/prediction_engine\" \"$BASE/services/api/\" || true"

echo
echo "[5] Would move microservices (if exist):"
echo "    mv \"$BASE/backend/event-bus\" \"$BASE/services/event-bus/\" || true"
echo "    mv \"$BASE/backend/metering\" \"$BASE/services/metering/\" || true"
echo "    mv \"$BASE/backend/workers\" \"$BASE/services/workers/\" || true"

echo
echo "[6] Would move infra:"
echo "    mv \"$BASE/docker-compose.yml\" \"$BASE/infra/docker/\""
echo "    mv \"$BASE/alertmanager\" \"$BASE/infra/\" || true"
echo "    mv \"$BASE/cluster-warzone.yaml\" \"$BASE/infra/\" || true"

echo
echo "[7] Would clean legacy / junk:"
echo "    rm -rf \"$BASE/backend/venv\""
echo "    rm -rf \"$BASE/backups\""
echo "    rm -rf \"$BASE/db-backups\""
echo "    rm -f  \"$BASE\"/*.dump"
echo "    rm -f  \"$BASE\"/*.tar.gz"
echo "    rm -f  \"$BASE/predictora_monolith.py\""
echo "    rm -f  \"$BASE/backup_restore.bat\" \"$BASE/backup_trastlayer.bat\""
echo "    rm -f  \"$BASE/fix-compose.sh\" \"$BASE/backend_refactor.sh\" \"$BASE/cleanup_phase1.sh\""

echo
echo "[DONE] DRY RUN ONLY — NO CHANGES APPLIED."
