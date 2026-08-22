#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/deploy/predictoraai"
BACKEND_DIR="$PROJECT_ROOT/backend"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

echo "[+] Using project root: $PROJECT_ROOT"

########################################
# 1. Add monitoring stack (Prometheus + Grafana + Loki)
########################################

MONITORING_DIR="$PROJECT_ROOT/monitoring"
mkdir -p "$MONITORING_DIR"

cat > "$MONITORING_DIR/docker-compose.yml" << 'EOF'
version: "3.9"

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - monitoring_internal
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    networks:
      - monitoring_internal
    restart: unless-stopped

  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    networks:
      - monitoring_internal
    restart: unless-stopped

networks:
  monitoring_internal:
    driver: bridge
EOF

cat > "$MONITORING_DIR/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'predictoraai-backend'
    static_configs:
      - targets: ['predictoraai-backend:8000']
EOF

echo "[+] Monitoring stack scaffolded at $MONITORING_DIR"

########################################
# 2. Patch main backend for metrics + health
########################################

MAIN_FILE="$BACKEND_DIR/main.py"

if ! grep -q "prometheus_client" "$MAIN_FILE"; then
  cat >> "$MAIN_FILE" << 'EOF'

# --- Enterprise Observability ---
from prometheus_client import Counter, Histogram, generate_latest
from fastapi import Request

REQUEST_COUNT = Counter(
    "predictora_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)

REQUEST_LATENCY = Histogram(
    "predictora_request_latency_seconds",
    "Request latency",
    ["endpoint"],
)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    import time
    start = time.time()
    response = await call_next(request)
    elapsed = time.time() - start

    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code,
    ).inc()

    REQUEST_LATENCY.labels(
        endpoint=request.url.path,
    ).observe(elapsed)

    return response


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/metrics")
async def metrics():
    from fastapi.responses import PlainTextResponse
    return PlainTextResponse(generate_latest(), media_type="text/plain")
EOF
  echo "[+] Added metrics + health endpoints to main.py"
else
  echo "[!] Metrics already present in main.py, skipping"
fi

########################################
# 3. Add API key + usage logging (monetization)
########################################

API_MODELS="$BACKEND_DIR/api_keys_models.py"
API_MIGRATION_NOTE="$BACKEND_DIR/API_KEYS_MIGRATION.txt"

cat > "$API_MODELS" << 'EOF'
from sqlalchemy import Column, String, Boolean, Integer, DateTime
from datetime import datetime
from .database import Base


class ApiKey(Base):
    __tablename__ = "api_keys"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String, unique=True, index=True, nullable=False)
    owner = Column(String, index=True, nullable=False)
    active = Column(Boolean, default=True)
    rate_limit_per_minute = Column(Integer, default=60)
    created_at = Column(DateTime, default=datetime.utcnow)


class ApiUsage(Base):
    __tablename__ = "api_usage"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String, index=True, nullable=False)
    endpoint = Column(String, nullable=False)
    status_code = Column(Integer, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
EOF

cat > "$API_MIGRATION_NOTE" << 'EOF'
-- Add to your Alembic/Prisma migrations:

CREATE TABLE api_keys (
  id SERIAL PRIMARY KEY,
  key VARCHAR(255) UNIQUE NOT NULL,
  owner VARCHAR(255) NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  rate_limit_per_minute INT DEFAULT 60,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE api_usage (
  id SERIAL PRIMARY KEY,
  key VARCHAR(255) NOT NULL,
  endpoint VARCHAR(255) NOT NULL,
  status_code INT NOT NULL,
  timestamp TIMESTAMP DEFAULT NOW()
);
EOF

echo "[+] API key + usage models scaffolded"

########################################
# 4. Add security middleware (rate limiting + lockdown)
########################################

SECURITY_FILE="$BACKEND_DIR/security_middleware.py"

cat > "$SECURITY_FILE" << 'EOF'
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
import os
import time
from collections import defaultdict

RATE_BUCKET = defaultdict(list)
LOCKDOWN_FLAG_FILE = "/tmp/predictora_lockdown.flag"


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host
        now = time.time()
        window = 60
        limit = int(os.getenv("GLOBAL_RATE_LIMIT_PER_MINUTE", "120"))

        RATE_BUCKET[client_ip] = [
            ts for ts in RATE_BUCKET[client_ip] if now - ts < window
        ]
        RATE_BUCKET[client_ip].append(now)

        if len(RATE_BUCKET[client_ip]) > limit:
            raise HTTPException(status_code=429, detail="Rate limit exceeded")

        return await call_next(request)


class LockdownMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if os.path.exists(LOCKDOWN_FLAG_FILE):
            # Allow only admin endpoints
            if not request.url.path.startswith("/admin"):
                raise HTTPException(status_code=503, detail="System in lockdown mode")
        return await call_next(request)
EOF

# Patch main.py to include middleware
if ! grep -q "RateLimitMiddleware" "$MAIN_FILE"; then
  cat >> "$MAIN_FILE" << 'EOF'

# --- Enterprise Security Middleware ---
from security_middleware import RateLimitMiddleware, LockdownMiddleware

app.add_middleware(RateLimitMiddleware)
app.add_middleware(LockdownMiddleware)
EOF
  echo "[+] Added security middleware wiring to main.py"
else
  echo "[!] Security middleware already wired, skipping"
fi

########################################
# 5. Add audit log model (compliance)
########################################

AUDIT_FILE="$BACKEND_DIR/audit_models.py"
AUDIT_NOTE="$BACKEND_DIR/AUDIT_MIGRATION.txt"

cat > "$AUDIT_FILE" << 'EOF'
from sqlalchemy import Column, String, Integer, DateTime, JSON
from datetime import datetime
from .database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    actor = Column(String, index=True)
    action = Column(String, index=True)
    resource = Column(String, index=True)
    metadata = Column(JSON)
    timestamp = Column(DateTime, default=datetime.utcnow)
EOF

cat > "$AUDIT_NOTE" << 'EOF'
CREATE TABLE audit_logs (
  id SERIAL PRIMARY KEY,
  actor VARCHAR(255),
  action VARCHAR(255),
  resource VARCHAR(255),
  metadata JSONB,
  timestamp TIMESTAMP DEFAULT NOW()
);
EOF

echo "[+] Audit log model scaffolded"

########################################
# 6. Restart stack
########################################

cd "$PROJECT_ROOT"
echo "[+] Restarting stack with fresh build"
docker compose down
docker compose build --no-cache
docker compose up -d

echo "[+] Enterprise scaffolding applied. Check:"
echo "  - /health"
echo "  - /metrics"
echo "  - rate limiting under load"
echo "  - lockdown: touch /tmp/predictora_lockdown.flag"
echo "  - API keys: models + migrations"
echo "  - audit logs: models + migrations"
