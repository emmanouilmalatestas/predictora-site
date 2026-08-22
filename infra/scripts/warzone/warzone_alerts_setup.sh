#!/bin/bash

set -e

echo "🔥 WARZONE ALERT PACK INSTALLER STARTED"

PROM_DIR="/home/deploy/predictoraai/prometheus"

cd "$PROM_DIR"

echo "📁 Creating WARZONE rule files..."

# -------------------------
# BACKEND RULES
# -------------------------
cat > warzone-backend.yml << 'EOF'
groups:
  - name: warzone-backend
    rules:
      - alert: BackendDown
        expr: up{job="backend"} == 0
        for: 15s
        labels:
          severity: critical
        annotations:
          summary: "Backend is DOWN"
          description: "The backend service is unreachable."

      - alert: BackendHighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="backend"}[2m])) > 0.5
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High backend latency"
          description: "95th percentile latency > 500ms."

      - alert: Backend5xxSpike
        expr: rate(http_requests_total{job="backend",status=~"5.."}[2m]) > 1
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Backend 5xx spike"
          description: "More than 1 error/sec in the last 2 minutes."
EOF

# -------------------------
# TRAEFIK RULES
# -------------------------
cat > warzone-traefik.yml << 'EOF'
groups:
  - name: warzone-traefik
    rules:
      - alert: Traefik5xxSpike
        expr: rate(traefik_service_requests_total{code=~"5.."}[2m]) > 1
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Traefik 5xx spike"
          description: "Edge layer returning 5xx errors."

      - alert: TraefikDown
        expr: up{job="traefik"} == 0
        for: 15s
        labels:
          severity: critical
        annotations:
          summary: "Traefik is DOWN"
          description: "Reverse proxy unreachable."
EOF

# -------------------------
# DATABASE RULES
# -------------------------
cat > warzone-db.yml << 'EOF'
groups:
  - name: warzone-db
    rules:
      - alert: DatabaseDown
        expr: pg_up == 0
        for: 10s
        labels:
          severity: critical
        annotations:
          summary: "Database is DOWN"
          description: "PostgreSQL is unreachable."

      - alert: DatabaseConnectionsHigh
        expr: pg_stat_activity_count > 90
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High DB connections"
          description: "More than 90 active connections."
EOF

# -------------------------
# NODE / HARDWARE RULES
# -------------------------
cat > warzone-node.yml << 'EOF'
groups:
  - name: warzone-node
    rules:
      - alert: HighCPU
        expr: rate(node_cpu_seconds_total{mode="idle"}[2m]) < 0.2
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU idle < 20%."

      - alert: LowDiskSpace
        expr: node_filesystem_avail_bytes{mountpoint="/"} < 5 * 1024 * 1024 * 1024
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Less than 5GB remaining."

      - alert: HighMemoryUsage
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.15
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Less than 15% RAM available."
EOF

# -------------------------
# MONITORING SELF‑CHECK RULES
# -------------------------
cat > warzone-monitoring.yml << 'EOF'
groups:
  - name: warzone-monitoring
    rules:
      - alert: PrometheusDown
        expr: up{job="prometheus"} == 0
        for: 15s
        labels:
          severity: critical
        annotations:
          summary: "Prometheus is DOWN"
          description: "Prometheus is unreachable."

      - alert: ScrapeFailures
        expr: rate(prometheus_target_scrapes_exceeded_sample_limit_total[2m]) > 0
        for: 30s
        labels:
          severity: warning
        annotations:
          summary: "Scrape failures detected"
          description: "Prometheus is failing to scrape targets."

      - alert: AlertmanagerDeliveryFailures
        expr: rate(alertmanager_notifications_failed_total[2m]) > 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Alert delivery failures"
          description: "Alertmanager cannot deliver alerts."
EOF

echo "⚙️ Updating prometheus.yml rule_files..."

if ! grep -q "warzone-backend.yml" prometheus.yml; then
cat >> prometheus.yml << 'EOF'

rule_files:
  - "warzone-backend.yml"
  - "warzone-traefik.yml"
  - "warzone-db.yml"
  - "warzone-node.yml"
  - "warzone-monitoring.yml"
EOF
fi

echo "🔍 Validating Prometheus config..."
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

echo "🔄 Restarting Prometheus..."
docker compose restart prometheus

echo "✅ WARZONE ALERT PACK INSTALLED SUCCESSFULLY"
