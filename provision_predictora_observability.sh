#!/usr/bin/env bash
set -euo pipefail

echo "🚀 PredictoraAI Observability & Reliability Stack Provisioning"
BASE_DIR="$(pwd)/observability"
mkdir -p "$BASE_DIR"

echo "📁 Using local config dir: $BASE_DIR"

# ================================
# 1) Alertmanager config
# ================================
ALERTMGR_DIR="$BASE_DIR/alertmanager"
mkdir -p "$ALERTMGR_DIR"

cat > "$ALERTMGR_DIR/alertmanager.yml" << 'EOF'
global:
  resolve_timeout: 5m

route:
  receiver: "slack_critical"
  group_by: ['alertname', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 2h

  routes:
    - match:
        severity: critical
      receiver: "slack_critical"

    - match:
        severity: warning
      receiver: "slack_warning"

receivers:
  - name: "slack_critical"
    slack_configs:
      - channel: "#predictora-alerts"
        send_resolved: true
        api_url: "${SLACK_WEBHOOK}"

  - name: "slack_warning"
    slack_configs:
      - channel: "#predictora-warnings"
        send_resolved: true
        api_url: "${SLACK_WEBHOOK}"
EOF

echo "✅ Alertmanager config → $ALERTMGR_DIR/alertmanager.yml"

# ================================
# 2) Blackbox exporter config
# ================================
BLACKBOX_DIR="$BASE_DIR/blackbox"
mkdir -p "$BLACKBOX_DIR"

cat > "$BLACKBOX_DIR/blackbox.yml" << 'EOF'
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      method: GET

  tcp_connect:
    prober: tcp
    timeout: 5s

  dns_lookup:
    prober: dns
    dns:
      query_name: "predictora.ai"
EOF

echo "✅ Blackbox config → $BLACKBOX_DIR/blackbox.yml"

# ================================
# 3) Prometheus rules (model + business + blackbox)
# ================================
PROM_RULES_DIR="$BASE_DIR/prometheus-rules"
mkdir -p "$PROM_RULES_DIR"

cat > "$PROM_RULES_DIR/predictora_model_rules.yml" << 'EOF'
groups:
- name: predictora_model_performance
  rules:
  - alert: ModelLatencyHigh
    expr: histogram_quantile(0.95, sum(rate(model_latency_seconds_bucket[5m])) by (le, model)) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      description: "Model latency p95 > 1s for 5m"
      summary: "High model latency"

  - alert: ModelAccuracyDrop
    expr: (predictora_model_accuracy < 0.8)
    for: 15m
    labels:
      severity: critical
    annotations:
      description: "Model accuracy < 80% for 15m"
      summary: "Model accuracy degradation"
EOF

cat > "$PROM_RULES_DIR/predictora_business_rules.yml" << 'EOF'
groups:
- name: predictora_business_anomalies
  rules:
  - alert: RevenueDropAnomaly
    expr: (predictora_revenue_last_hour < predictora_revenue_baseline_24h * 0.7)
    for: 15m
    labels:
      severity: critical
    annotations:
      description: "Revenue dropped more than 30% vs 24h baseline"
      summary: "Revenue anomaly"

  - alert: ActiveUsersDropAnomaly
    expr: (predictora_active_users_last_hour < predictora_active_users_baseline_24h * 0.7)
    for: 30m
    labels:
      severity: warning
    annotations:
      description: "Active users dropped more than 30% vs 24h baseline"
      summary: "User activity anomaly"
EOF

cat > "$PROM_RULES_DIR/predictora_blackbox_rules.yml" << 'EOF'
groups:
- name: predictora_blackbox
  rules:
  - alert: PredictoraFrontendDown
    expr: probe_success{job="blackbox", target="https://predictora.ai"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      description: "predictora.ai is not reachable"
      summary: "Frontend down"

  - alert: PredictoraAPIHealthFail
    expr: probe_success{job="blackbox", target="https://api.predictora.ai/health"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      description: "API health endpoint is failing"
      summary: "API down"
EOF

echo "✅ Prometheus rules → $PROM_RULES_DIR"

# ================================
# 4) Prometheus remote_write snippet
# ================================
cat > "$PROM_RULES_DIR/remote_write_snippet.yml" << 'EOF'
remote_write:
  - url: "http://victoriametrics:8428/api/v1/write"
    queue_config:
      capacity: 50000
      max_shards: 30
      min_shards: 4
      max_samples_per_send: 20000
EOF

echo "✅ Prometheus remote_write snippet → $PROM_RULES_DIR/remote_write_snippet.yml"

# ================================
# 5) Loki retention config
# ================================
LOKI_DIR="$BASE_DIR/loki"
mkdir -p "$LOKI_DIR"

cat > "$LOKI_DIR/loki_retention.yml" << 'EOF'
compactor:
  working_directory: /loki/compactor
  shared_store: filesystem
  retention_enabled: true

limits_config:
  retention_period: 168h  # 7 days
EOF

echo "✅ Loki retention config → $LOKI_DIR/loki_retention.yml"

# ================================
# 6) FastAPI / Model metrics snippet
# ================================
APP_DIR="$BASE_DIR/app-metrics"
mkdir -p "$APP_DIR"

cat > "$APP_DIR/model_metrics_example.py" << 'EOF'
from prometheus_client import Histogram, Gauge

model_latency = Histogram(
    "model_latency_seconds",
    "Model inference latency",
    ["model"]
)

model_accuracy = Gauge(
    "predictora_model_accuracy",
    "Model accuracy",
    ["model"]
)

# Example usage:
# model_latency.labels(model="credit_risk").observe(0.23)
# model_accuracy.labels(model="credit_risk").set(0.91)
EOF

echo "✅ Model metrics example → $APP_DIR/model_metrics_example.py"

# ================================
# 7) README / NEXT STEPS
# ================================
cat > "$BASE_DIR/README_PREDICTORAAI_OBSERVABILITY.txt" << 'EOF'
PredictoraAI Observability & Reliability Stack
=============================================

Files generated:

1) Alertmanager:
   - alertmanager.yml
   Suggested path: /etc/alertmanager/alertmanager.yml

2) Blackbox Exporter:
   - blackbox.yml
   Suggested path: /etc/blackbox_exporter/blackbox.yml

3) Prometheus rules:
   - predictora_model_rules.yml
   - predictora_business_rules.yml
   - predictora_blackbox_rules.yml
   Suggested path: /etc/prometheus/rules/

4) Prometheus remote_write snippet:
   - remote_write_snippet.yml
   Merge into your main prometheus.yml under 'remote_write'.

5) Loki:
   - loki_retention.yml
   Merge into your main loki config.

6) App metrics:
   - model_metrics_example.py
   Integrate into your FastAPI / worker services.

IMPORTANT:
- Move these files with sudo to their final locations.
- Validate configs before reload:
  - promtool check config / rules
  - amtool check-config
- Reload services via systemd or docker compose.

EOF

echo "✅ README with next steps → $BASE_DIR/README_PREDICTORAAI_OBSERVABILITY.txt"

echo "🎯 DONE: All configs generated under: $BASE_DIR"
echo "⚠️ Next: move them with sudo to real paths and reload Prometheus / Alertmanager / Loki / Blackbox."
