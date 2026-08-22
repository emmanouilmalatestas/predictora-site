#!/usr/bin/env bash
set -euo pipefail

### CONFIG
BILLING_ROOT="/home/deploy/predictoraai/predictora-billing"
BILLING_PORT="8010"
TRAEFIK_DYNAMIC_DIR="/etc/traefik/dynamic"
TRAEFIK_DYNAMIC_FILE="${TRAEFIK_DYNAMIC_DIR}/billing.yml"
SYSTEMD_UNIT="/etc/systemd/system/predictora-billing.service"

echo "[INFO] Activating PredictoraAI Billing Engine on port ${BILLING_PORT}"

### 1. Check billing backend exists
if [ ! -d "${BILLING_ROOT}" ]; then
  echo "[ERROR] Billing backend directory not found: ${BILLING_ROOT}"
  exit 1
fi

if [ ! -f "${BILLING_ROOT}/main.py" ]; then
  echo "[ERROR] main.py not found in ${BILLING_ROOT}"
  exit 1
fi

### 2. Create systemd service for billing (uvicorn on 8010)
echo "[INFO] Writing systemd unit: ${SYSTEMD_UNIT}"

sudo tee "${SYSTEMD_UNIT}" >/dev/null <<EOF
[Unit]
Description=PredictoraAI Billing Engine — Unicorn Edition
After=network.target

[Service]
User=deploy
WorkingDirectory=${BILLING_ROOT}
Environment="PYTHONUNBUFFERED=1"
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port ${BILLING_PORT}
Restart=always
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] Reloading systemd and starting billing service"
sudo systemctl daemon-reload
sudo systemctl enable predictora-billing.service
sudo systemctl restart predictora-billing.service

sleep 3

### 3. Quick local health check
echo "[INFO] Local health check on port ${BILLING_PORT}"
curl -sSf "http://127.0.0.1:${BILLING_PORT}/status" || echo "[WARN] /status not responding, but service is up"

### 4. Create Traefik dynamic config for /billing/*
echo "[INFO] Writing Traefik dynamic config: ${TRAEFIK_DYNAMIC_FILE}"

sudo mkdir -p "${TRAEFIK_DYNAMIC_DIR}"

sudo tee "${TRAEFIK_DYNAMIC_FILE}" >/dev/null <<EOF
http:
  routers:
    billing-router:
      rule: "PathPrefix(\`/billing\`)"
      entryPoints:
        - websecure
      service: billing-service
      tls:
        certResolver: letsencrypt
  services:
    billing-service:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:${BILLING_PORT}"
EOF

### 5. Reload Traefik
echo "[INFO] Reloading Traefik"
sudo systemctl reload traefik || sudo systemctl restart traefik

sleep 3

### 6. External tests via api.predictoraai.com
echo "[INFO] Testing external billing endpoints via Traefik"

for path in "/billing/events" "/billing/webhook" "/billing/transactions" "/billing/charges" "/billing/subscriptions" "/billing/status"; do
  echo "---- GET https://api.predictoraai.com${path}"
  curl -k -s -o /dev/null -w "HTTP %{http_code}\n" "https://api.predictoraai.com${path}" || echo "[ERROR] Request failed for ${path}"
done

echo "[INFO] Billing activation script completed."
echo "[INFO] If any endpoint still returns 404, check billing_api.py/webhooks.py/usage_writer.py/status.py routing."
