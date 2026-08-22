#!/usr/bin/env bash
set -euo pipefail

BACKEND="/home/deploy/predictoraai/backend"

echo "[+] Adding health router"
cat > "$BACKEND/health_router.py" << 'EOF'
from fastapi import APIRouter
from datetime import datetime

router = APIRouter(prefix="/health", tags=["health"])

@router.get("/live")
def live():
    return {"status": "ok", "time": datetime.utcnow().isoformat()}

@router.get("/ready")
def ready():
    # εδώ αργότερα μπορείς να βάλεις checks για DB, Stripe, κλπ.
    return {"status": "ready"}
EOF

echo "[+] Wiring health router into main.py"
MAIN="$BACKEND/main.py"

if ! grep -q "health_router" "$MAIN"; then
  cat >> "$MAIN" << 'EOF'

# --- Health / Readiness ---
from health_router import router as health_router
app.include_router(health_router)
EOF
else
  echo "[!] health_router already wired, skipping"
fi

echo "[+] Patching backend Dockerfile with HEALTHCHECK"
DOCKERFILE="$BACKEND/Dockerfile"

if ! grep -q "HEALTHCHECK" "$DOCKERFILE"; then
  cat >> "$DOCKERFILE" << 'EOF'

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/health/live || exit 1
EOF
else
  echo "[!] HEALTHCHECK already present in backend Dockerfile, skipping"
fi

echo "[+] Rebuilding backend with health endpoints"
cd /home/deploy/predictoraai
docker compose build predictoraai-backend --no-cache
docker compose up -d

echo "[+] Phase 4 base resilience complete."
echo "    - /health/live for liveness"
echo "    - /health/ready for readiness"
echo "    - Container HEALTHCHECK wired"
