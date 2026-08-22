#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/deploy/predictoraai"
OBS="$ROOT/observability"
PROM="$OBS/prometheus"
GRAF="$OBS/grafana"

echo "[*] Setting up Observability Stack…"

mkdir -p "$PROM" "$GRAF/provisioning/datasources" "$GRAF/provisioning/dashboards"

###############################################
# 1. Prometheus config
###############################################
cat > "$PROM/prometheus.yml" << 'EOF'
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: "traefik"
    static_configs:
      - targets: ["traefik:8080"]

  - job_name: "backend"
    static_configs:
      - targets: ["predictoraai-backend:8000"]

  - job_name: "revenue_exporter"
    static_configs:
      - targets: ["predictoraai-revenue-exporter:8000"]
EOF

###############################################
# 2. Grafana datasource
###############################################
cat > "$GRAF/provisioning/datasources/prometheus.yml" << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

###############################################
# 3. Grafana dashboards auto-load
###############################################
cat > "$GRAF/provisioning/dashboards/dashboards.yml" << 'EOF'
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

mkdir -p "$GRAF/dashboards"

###############################################
# 4. Add Traefik metrics flag
###############################################
echo "[*] Ensuring Traefik metrics enabled…"

if ! grep -q "metrics.prometheus" "$ROOT/docker-compose.yml"; then
  sed -i '/traefik:/a \
      - "--metrics.prometheus=true"\n\
      - "--metrics.prometheus.entrypoint=traefik"' "$ROOT/docker-compose.yml"
fi

###############################################
# 5. Restart stack
###############################################
echo "[*] Restarting Prometheus + Grafana + Traefik…"

docker compose down
docker compose up -d

echo "[✓] Observability stack ready."
