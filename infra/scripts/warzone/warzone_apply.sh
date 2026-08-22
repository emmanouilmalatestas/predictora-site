#!/bin/bash
set -e

BASE="/home/deploy/predictoraai"
BACKUP="$BASE/_warzone_backup_$(date +%Y%m%d_%H%M%S)"

echo "=== WARZONE 9000 REPO REBUILD (APPLY MODE) ==="
echo "[*] BASE:   $BASE"
echo "[*] BACKUP: $BACKUP"

echo "[1] Creating backup..."
mkdir -p "$BACKUP"
cp -r "$BASE/admin-frontend" "$BACKUP/"
cp -r "$BASE/frontend" "$BACKUP/"
cp -r "$BASE/backend" "$BACKUP/"
cp -r "$BASE/docker-compose.yml" "$BACKUP/"

echo "[2] Creating new structure..."
mkdir -p "$BASE/apps/admin"
mkdir -p "$BASE/apps/client"
mkdir -p "$BASE/services/api"
mkdir -p "$BASE/services/event-bus"
mkdir -p "$BASE/services/metering"
mkdir -p "$BASE/services/workers"
mkdir -p "$BASE/infra/docker"
mkdir -p "$BASE/infra/traefik"
mkdir -p "$BASE/infra/scripts"
mkdir -p "$BASE/shared"

echo "[3] Moving frontends..."
mv "$BASE/admin-frontend"/* "$BASE/apps/admin/"
mv "$BASE/frontend"/* "$BASE/apps/client/"

echo "[4] Moving backend core..."
mv "$BASE/backend/app" "$BASE/services/api/"
mv "$BASE/backend/src" "$BASE/services/api/"
mv "$BASE/backend/models" "$BASE/services/api/" || true
mv "$BASE/backend/services" "$BASE/services/api/" || true
mv "$BASE/backend/prediction_engine" "$BASE/services/api/" || true

echo "[5] Moving microservices..."
mv "$BASE/backend/event-bus" "$BASE/services/event-bus/" || true
mv "$BASE/backend/metering" "$BASE/services/metering/" || true
mv "$BASE/backend/workers" "$BASE/services/workers/" || true

echo "[6] Moving infra..."
mv "$BASE/docker-compose.yml" "$BASE/infra/docker/"
mv "$BASE/alertmanager" "$BASE/infra/" || true
mv "$BASE/cluster-warzone.yaml" "$BASE/infra/" || true

echo "[7] Cleaning legacy..."
rm -rf "$BASE/backend/venv"
rm -rf "$BASE/backups"
rm -rf "$BASE/db-backups"
rm -f  "$BASE"/*.dump
rm -f  "$BASE"/*.tar.gz
rm -f  "$BASE/predictora_monolith.py"
rm -f  "$BASE/backup_restore.bat" "$BASE/backup_trastlayer.bat"
rm -f  "$BASE/fix-compose.sh" "$BASE/backend_refactor.sh" "$BASE/cleanup_phase1.sh"

echo "[DONE] WARZONE 9000 REBUILD COMPLETE."
