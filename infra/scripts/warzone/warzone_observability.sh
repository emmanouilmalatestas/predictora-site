#!/usr/bin/env bash
set -e

ROOT="/home/deploy/predictoraai"

echo "[1/6] Creating directories..."
mkdir -p "$ROOT/prometheus"
mkdir -p "$ROOT/alertmanager"
mkdir -p "$ROOT/grafana/provisioning/dashboards"

########################################
# 1. PROMETHEUS ALERT RULES
########################################
cat > "$ROOT/prometheus/alert.rules.yml" << 'EOF'
groups:
  - name: warzone-alerts
    rules:
      # Backend down
      - alert: BackendDown
        expr: up{job="backend"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Backend is down"
          description: "The backend job is not responding for more than 1 minute."

      # High backend latency (p95 > 500ms)
      - alert: BackendHighLatency
        expr: histogram_quantile(0.95, sum(rate(backend_request_duration_seconds_bucket[5m])) by (le)) * 1000 > 500
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High backend latency (p95 > 500ms)"
          description: "Backend p95 latency is above 500ms for 5 minutes."

      # Traefik 5xx spike
      - alert: TraefikHigh5xx
        expr: sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) > 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High 5xx rate on Traefik"
          description: "Traefik is returning 5xx errors at a high rate."

      # Node CPU high
      - alert: NodeHighCPU
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on node"
          description: "Node CPU usage is above 85% for 10 minutes."

      # Node memory high
      - alert: NodeHighMemory
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on node"
          description: "Node memory usage is above 85% for 10 minutes."

      # WARZONE backend health
      - alert: WarzoneBackendUnhealthy
        expr: warzone_backend_health == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "WARZONE backend health is 0"
          description: "Guardian reports backend health = 0."

      # WARZONE containers low
      - alert: WarzoneContainersLow
        expr: warzone_containers_running < 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "WARZONE containers running below threshold"
          description: "Guardian reports low number of running containers."
EOF

########################################
# 2. ALERTMANAGER CONFIG (SLACK + TELEGRAM)
########################################
cat > "$ROOT/alertmanager/alertmanager.yml" << 'EOF'
global:
  resolve_timeout: 5m

  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

route:
  receiver: 'default'
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h

receivers:
  - name: 'default'
    slack_configs:
      - channel: '#warzone-alerts'
        send_resolved: true
        title: '{{ .CommonAnnotations.summary }}'
        text: '{{ range .Alerts }}*{{ .Labels.severity | toUpper }}* - {{ .Annotations.description }}\n{{ end }}'

    webhook_configs:
      - url: 'https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMessage'
        send_resolved: true
        http_config:
          follow_redirects: true
        max_alerts: 10
EOF

echo
echo ">>> IMPORTANT: Edit alertmanager.yml and set:"
echo "    - YOUR Slack webhook URL"
echo "    - YOUR Telegram bot token"
echo

########################################
# 3. GRAFANA DASHBOARD PROVIDER
########################################
cat > "$ROOT/grafana/provisioning/dashboards/warzone-dashboard.yml" << 'EOF'
apiVersion: 1

providers:
  - name: 'warzone'
    orgId: 1
    folder: 'WARZONE'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

########################################
# 4. GRAFANA WARZONE DASHBOARD JSON
########################################
cat > "$ROOT/grafana/provisioning/dashboards/warzone-dashboard.json" << 'EOF'
{
  "title": "WARZONE Dashboard",
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 1,
  "panels": [
    {
      "type": "gauge",
      "title": "WARZONE Backend Health",
      "targets": [
        { "expr": "warzone_backend_health" }
      ],
      "fieldConfig": {
        "defaults": {
          "min": 0,
          "max": 1,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "color": "red", "value": 0 },
              { "color": "green", "value": 1 }
            ]
          }
        }
      },
      "gridPos": { "x": 0, "y": 0, "w": 6, "h": 6 }
    },
    {
      "type": "gauge",
      "title": "WARZONE Containers Running",
      "targets": [
        { "expr": "warzone_containers_running" }
      ],
      "fieldConfig": {
        "defaults": {
          "min": 0,
          "max": 20,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "color": "red", "value": 0 },
              { "color": "yellow", "value": 5 },
              { "color": "green", "value": 10 }
            ]
          }
        }
      },
      "gridPos": { "x": 6, "y": 0, "w": 6, "h": 6 }
    },
    {
      "type": "timeseries",
      "title": "Backend Latency p95 (ms)",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(backend_request_duration_seconds_bucket[5m])) by (le)) * 1000"
        }
      ],
      "gridPos": { "x": 0, "y": 6, "w": 12, "h": 6 }
    },
    {
      "type": "timeseries",
      "title": "PredictoraAI Inference Latency p95 (ms)",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(predictora_inference_duration_seconds_bucket[5m])) by (le)) * 1000"
        }
      ],
      "gridPos": { "x": 0, "y": 12, "w": 12, "h": 6 }
    },
    {
      "type": "timeseries",
      "title": "Traefik Request Duration p95 (s)",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(traefik_service_request_duration_seconds_bucket[5m])) by (le))"
        }
      ],
      "gridPos": { "x": 0, "y": 18, "w": 12, "h": 6 }
    },
    {
      "type": "timeseries",
      "title": "Requests Per Second (Traefik)",
      "targets": [
        {
          "expr": "sum(rate(traefik_service_requests_total[1m]))"
        }
      ],
      "gridPos": { "x": 0, "y": 24, "w": 12, "h": 6 }
    },
    {
      "type": "timeseries",
      "title": "Traefik Error Rates (4xx / 5xx)",
      "targets": [
        {
          "expr": "sum(rate(traefik_service_requests_total{code=~\"4..\"}[5m]))",
          "legendFormat": "4xx"
        },
        {
          "expr": "sum(rate(traefik_service_requests_total{code=~\"5..\"}[5m]))",
          "legendFormat": "5xx"
        }
      ],
      "gridPos": { "x": 0, "y": 30, "w": 12, "h": 6 }
    },
    {
      "type": "timeseries",
      "title": "Node CPU Usage (%)",
      "targets": [
        {
          "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
        }
      ],
      "gridPos": { "x": 0, "y": 36, "w": 6, "h": 6 }
    },
    {
      "type": "timeseries",
      "title": "Node Memory Usage (%)",
      "targets": [
        {
          "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
        }
      ],
      "gridPos": { "x": 6, "y": 36, "w": 6, "h": 6 }
    },
    {
      "type": "timeseries",
      "title": "Backend Uptime (minutes)",
      "targets": [
        {
          "expr": "(time() - process_start_time_seconds{job=\"backend\"}) / 60"
        }
      ],
      "gridPos": { "x": 0, "y": 42, "w": 12, "h": 6 }
    },
    {
      "type": "table",
      "title": "Guardian Auto-Heal Events (if exported as metrics)",
      "targets": [
        {
          "expr": "warzone_autoheal_events_total"
        }
      ],
      "gridPos": { "x": 0, "y": 48, "w": 12, "h": 6 }
    }
  ]
}
EOF

########################################
# 5. REMIND TO INCLUDE ALERT RULES IN PROMETHEUS CONFIG
########################################
echo
echo "[2/6] Make sure prometheus.yml includes:"
echo "  rule_files:"
echo "    - \"alert.rules.yml\""
echo
echo "If not, edit: $ROOT/prometheus/prometheus.yml"
echo

########################################
# 6. RESTART PROMETHEUS, ALERTMANAGER, GRAFANA
########################################
echo "[3/6] Restarting Prometheus, Alertmanager, Grafana..."
cd "$ROOT"
docker compose restart prometheus alertmanager grafana

echo
echo "======================================="
echo "WARZONE observability provisioning done"
echo "Now:"
echo "  1) Edit alertmanager/alertmanager.yml and set Slack + Telegram"
echo "  2) Ensure prometheus.yml has rule_files: ['alert.rules.yml']"
echo "  3) Open Grafana -> Folder 'WARZONE' -> 'WARZONE Dashboard'"
echo "======================================="
