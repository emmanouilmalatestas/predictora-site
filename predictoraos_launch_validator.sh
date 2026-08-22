#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/deploy/predictoraai"
BACKEND_APP="$BASE_DIR/backend/app"
VENV_DIR="$BACKEND_APP/venv"
PYTHON="$VENV_DIR/bin/python"

echo "=== PredictoraOS Launch Validator ==="
echo "Starting full launch validation..."
echo

# 0) Containers
echo "=== 0) Containers ==="
docker ps --format '{{.Names}} {{.Status}}' \
  | grep -E 'predictora-backend|predictoraai-frontend|predictoraai-admin-frontend|predictoraai-db|predictora-redis|guardian|revenue-exporter' \
  || echo "⚠ Missing core containers"
echo

# 1) API Core
echo "=== 1) API Core ==="
curl -sk https://api.predictoraai.com/health || echo "❌ API health FAILED"
echo

# 2) Frontend / Admin
echo "=== 2) Frontend / Admin ==="
FRONT_MAIN=$(curl -sk -o /dev/null -w "%{http_code}" https://predictoraai.com/)
FRONT_WWW=$(curl -sk -o /dev/null -w "%{http_code}" https://www.predictoraai.com/)
ADMIN_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://admin.predictoraai.com/)

echo "Frontend main: $FRONT_MAIN"
echo "Frontend www:  $FRONT_WWW"
echo "Admin:         $ADMIN_STATUS"
echo

# 3) Billing / Revenue / Usage suites
echo "=== 3) Billing / Revenue / Usage Suites ==="
if [ -d "$VENV_DIR" ]; then
  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"
fi

echo "--- Billing suite ---"
$PYTHON "$BACKEND_APP/scripts/predictora_enterprise_certify.py" --suite billing || echo "❌ Billing suite FAILED"
echo

echo "--- Usage suite ---"
$PYTHON "$BACKEND_APP/scripts/predictora_enterprise_certify.py" --suite usage || echo "❌ Usage suite FAILED"
echo

echo "--- Revenue exporter suite ---"
$PYTHON "$BACKEND_APP/scripts/predictora_enterprise_certify.py" --suite revenue || echo "❌ Revenue suite FAILED"
echo

# 4) Runtime / Replay suites
echo "=== 4) Runtime / Replay Suites ==="
echo "--- Runtime suite ---"
$PYTHON "$BACKEND_APP/scripts/predictora_enterprise_certify.py" --suite runtime || echo "❌ Runtime suite FAILED"
echo

echo "--- Replay suite ---"
$PYTHON "$BACKEND_APP/scripts/predictora_enterprise_certify.py" --suite replay || echo "❌ Replay suite FAILED"
echo

# 5) Workers / Guardian / Event bus
echo "=== 5) Workers / Guardian / Event Bus ==="
echo "--- Guardian logs ---"
docker logs guardian | tail -n 50 || echo "❌ Guardian logs unavailable"
echo

# 6) Monitoring / Routing
echo "=== 6) Monitoring / Routing ==="
echo "--- Prometheus ---"
curl -sk http://localhost:9090/ | head -n 3 || echo "❌ Prometheus unreachable"
echo

echo "--- Alertmanager ---"
curl -sk http://localhost:9093/ | head -n 3 || echo "❌ Alertmanager unreachable"
echo

echo "--- Loki ---"
curl -sk http://localhost:3100/ready || echo "❌ Loki not ready"
echo

echo "--- Traefik 502 scan ---"
if docker logs traefik 2>&1 | grep -q '"DownstreamStatus":502'; then
  echo "❌ Traefik has 502s"
else
  echo "✔ Traefik clean (no 502s)"
fi
echo

echo "=== Launch Validator Completed ==="
echo "Review sections above for launch readiness."
