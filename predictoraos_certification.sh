#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/deploy/predictoraai"
BACKEND_APP="$BASE_DIR/backend/app"
VENV_DIR="$BACKEND_APP/venv"
PYTHON="$VENV_DIR/bin/python"

echo "=== PredictoraOS Production Certification Engine ==="
echo "Starting full-stack validation..."
echo

# ------------------------------------------------------
# 1) Container Health
# ------------------------------------------------------
echo "=== 1) Container Health ==="
docker ps --format '{{.Names}} {{.Status}}' | grep -E \
'predictoraai-frontend|predictoraai-admin-frontend|predictoraai-db|predictora-redis|predictora-backend|guardian|revenue-exporter' \
|| echo "⚠ Κάποιο core container λείπει"

echo

# ------------------------------------------------------
# 2) Backend Health (api.predictoraai.com)
# ------------------------------------------------------
echo "=== 2) Backend Health ==="
if curl -sk https://api.predictoraai.com/health | grep -q '"status":"ok"'; then
  echo "✔ Backend health OK"
else
  echo "❌ Backend FAILED"
fi
echo

# ------------------------------------------------------
# 3) Frontend Health (predictoraai.com / www.predictoraai.com)
# ------------------------------------------------------
echo "=== 3) Frontend Health ==="
if curl -sk https://predictoraai.com/ | grep -qi "Predictora"; then
  echo "✔ Frontend OK (predictoraai.com)"
else
  echo "❌ Frontend FAILED (predictoraai.com)"
fi

if curl -sk https://www.predictoraai.com/ | grep -qi "Predictora"; then
  echo "✔ Frontend OK (www.predictoraai.com)"
else
  echo "❌ Frontend FAILED (www.predictoraai.com)"
fi
echo

# ------------------------------------------------------
# 4) Admin Frontend (admin.predictoraai.com)
# ------------------------------------------------------
echo "=== 4) Admin Frontend ==="
if curl -sk https://admin.predictoraai.com/ | grep -qi "runtime-explorer"; then
  echo "✔ Admin frontend OK"
else
  echo "❌ Admin frontend FAILED"
fi
echo

# ------------------------------------------------------
# 5) Billing Machine (ledger + wallet + usage)
# ------------------------------------------------------
echo "=== 5) Billing Machine ==="
# Ενεργοποίηση venv backend
if [ -d "$VENV_DIR" ]; then
  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"
fi

# Εδώ καλείς το certification / suites για billing.
# Αν έχεις run_certification.py + billing_suite.py:
if "$PYTHON" "$BACKEND_APP/run_certification.py" --suite billing 2>&1; then
  echo "✔ Billing machine OK"
else
  echo "❌ Billing machine FAILED"
fi
echo

# ------------------------------------------------------
# 6) Runtime Replay Engine
# ------------------------------------------------------
echo "=== 6) Runtime Replay Engine ==="
# Προσαρμόζεις στο δικό σου health endpoint (π.χ. /runtime-replay/health)
if curl -sk https://api.predictoraai.com/runtime-replay | jq '.meta.version' >/dev/null 2>&1; then
  echo "✔ Runtime replay OK"
else
  echo "❌ Runtime replay FAILED"
fi
echo

# ------------------------------------------------------
# 7) Runtime Topology Graph
# ------------------------------------------------------
echo "=== 7) Runtime Topology Graph ==="
if curl -sk https://api.predictoraai.com/runtime-topology \
  | jq '.meta.deterministic' 2>/dev/null | grep -q true; then
  echo "✔ Runtime topology OK"
else
  echo "❌ Runtime topology FAILED"
fi
echo

# ------------------------------------------------------
# 8) Guardian Worker (workers/worker.py)
# ------------------------------------------------------
echo "=== 8) Guardian Worker ==="
if docker logs guardian 2>&1 | grep -qi "Worker started"; then
  echo "✔ Guardian worker OK"
else
  echo "❌ Guardian worker FAILED"
fi
echo

# ------------------------------------------------------
# 9) Revenue Exporter
# ------------------------------------------------------
echo "=== 9) Revenue Exporter ==="
# Προσαρμόζεις στο health endpoint του revenue exporter (π.χ. /health ή /metrics)
if curl -sk http://revenue-exporter:8000/health 2>/dev/null | grep -q '"status":"ok"'; then
  echo "✔ Revenue exporter OK"
else
  echo "❌ Revenue exporter FAILED"
fi
echo

# ------------------------------------------------------
# 10) Monitoring Stack (Prometheus / Loki / Alertmanager)
# ------------------------------------------------------
echo "=== 10) Monitoring Stack ==="
PROM_OK=false
if curl -sk http://localhost:9090/-/healthy 2>/dev/null | grep -q "Prometheus is Healthy"; then
  PROM_OK=true
fi

if [ "$PROM_OK" = true ]; then
  echo "✔ Prometheus OK"
else
  echo "❌ Prometheus FAILED"
fi

if curl -sk http://localhost:9093/-/healthy 2>/dev/null | grep -q "OK"; then
  echo "✔ Alertmanager OK"
else
  echo "❌ Alertmanager FAILED"
fi

# Loki basic check
if curl -sk http://localhost:3100/ready 2>/dev/null | grep -q "ready"; then
  echo "✔ Loki OK"
else
  echo "❌ Loki FAILED"
fi
echo

# ------------------------------------------------------
# 11) Traefik Routing (502 scan)
# ------------------------------------------------------
echo "=== 11) Traefik Routing ==="
if ! docker logs traefik 2>&1 | grep -q '"DownstreamStatus":502'; then
  echo "✔ Traefik routing OK (no 502s detected)"
else
  echo "❌ Traefik routing has 502 errors"
fi
echo

echo "=== FINAL RESULT ==="
echo "Ανασκόπησε τα παραπάνω sections για production readiness."
