#!/bin/bash

set -e

echo "====================================="
echo "PREDICTORAAI WARZONE AUDIT"
echo "====================================="

ROOT=$(pwd)

echo
echo "[1] BACKUP"
mkdir -p backups
tar -czf backups/predictora_backup_$(date +%F_%H%M%S).tar.gz backend .env docker-compose.yml

echo
echo "[2] CHECK HEALTH"

curl -s https://api.predictoraai.com/health || true

echo
echo "[3] CHECK OPENAPI"

curl -s https://api.predictoraai.com/openapi.json > /tmp/openapi.json

if grep -q openapi /tmp/openapi.json
then
  echo "OPENAPI OK"
else
  echo "OPENAPI FAIL"
fi

echo
echo "[4] HARDCODED DB URLs"

grep -R "postgresql://" backend || true

echo
echo "[5] HARDCODED PASSWORDS"

grep -R "postgres:postgres" backend || true

echo
echo "[6] API SECRET REFERENCES"

grep -R "API_SECRET" backend .env || true

echo
echo "[7] VALIDATE_API_KEY"

find backend -name "validate_api_key.py"

echo
echo "[8] JWT"

grep -R "JWT_SECRET" backend || true

echo
echo "[9] ROLE CLAIM"

grep -R "\"role\"" backend || true

echo
echo "[10] LOGIN ROUTE"

grep -R "create_access_token" backend || true

echo
echo "[11] DOCKERFILE"

find . -name Dockerfile -print

echo
echo "[12] API KEY MIDDLEWARE"

grep -R "middleware(\"http\")" backend || true

echo
echo "[13] RBAC"

find backend/src/rbac -type f

echo
echo "[14] DATABASE MODELS"

find backend -iname "*model*" || true

echo
echo "[15] ALEMBIC"

find . -iname "*alembic*" || true

echo
echo "[16] SQLALCHEMY"

grep -R "sqlalchemy" backend || true

echo
echo "[17] USERS TABLE"

grep -R "users" backend || true

echo
echo "[18] SUBSCRIPTIONS"

grep -R "subscription" backend || true

echo
echo "[19] API KEYS"

grep -R "api_keys" backend || true

echo
echo "[20] SECURITY SCORE"

SCORE=0

[ -f backend/main.py ] && SCORE=$((SCORE+5))
[ -d backend/src/rbac ] && SCORE=$((SCORE+10))
[ -f backend/auth_pkg/routes.py ] && SCORE=$((SCORE+5))
[ -f backend/api_keys.py ] && SCORE=$((SCORE+5))

echo
echo "Current Score: $SCORE / 100"

echo
echo "AUDIT COMPLETE"
