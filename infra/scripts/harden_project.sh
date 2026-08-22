#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/deploy/predictoraai"

echo "[*] Full project hardening…"

############################################
# 1. Frontend hardening (Next.js)
############################################
FRONT_ENV="$ROOT/apps/client/.env.production"

mkdir -p "$(dirname "$FRONT_ENV")"

cat > "$FRONT_ENV" << 'EOF'
NODE_ENV=production
NEXT_TELEMETRY_DISABLED=1
EOF

echo "[*] Frontend .env.production written."

############################################
# 2. Backend hardening (Uvicorn/Gunicorn)
############################################
BACK_ENV="$ROOT/backend.env"

if [ -f "$BACK_ENV" ]; then
  cp "$BACK_ENV" "$BACK_ENV.bak_hardened" || true
fi

cat >> "$BACK_ENV" << 'EOF'

# Hardened Uvicorn/Gunicorn tuning
WEB_CONCURRENCY=4
UVICORN_WORKERS=4
UVICORN_TIMEOUT_KEEP_ALIVE=15
UVICORN_LIMIT_MAX_REQUESTS=1000
UVICORN_LIMIT_MAX_REQUESTS_JITTER=100
EOF

echo "[*] Backend env tuned."

############################################
# 3. Postgres performance + WAL tuning
############################################

DB_CONTAINER="predictoraai-db"
DB_USER="postgres"
DB_NAME="postgres"

echo "[*] Applying Postgres tuning via ALTER SYSTEM…"

docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" << 'EOF'
ALTER SYSTEM SET shared_buffers = '512MB';
ALTER SYSTEM SET effective_cache_size = '1536MB';
ALTER SYSTEM SET work_mem = '16MB';
ALTER SYSTEM SET maintenance_work_mem = '256MB';

ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET max_wal_size = '2GB';
ALTER SYSTEM SET min_wal_size = '512MB';
ALTER SYSTEM SET checkpoint_timeout = '15min';
ALTER SYSTEM SET checkpoint_completion_target = '0.9';

ALTER SYSTEM SET synchronous_commit = 'on';
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

ALTER SYSTEM SET max_connections = 100;
EOF

echo "[*] Postgres ALTER SYSTEM applied. Restarting DB…"

docker restart "$DB_CONTAINER"

############################################
# 4. Restart core services
############################################

echo "[*] Restarting backend + frontend…"
docker restart predictoraai-backend || true
docker restart predictoraai-frontend || true

echo "[✓] Full project hardening completed."
