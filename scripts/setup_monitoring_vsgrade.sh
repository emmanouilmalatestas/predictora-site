#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MON_DIR="${BASE_DIR}/monitoring"
PROM_DIR="${MON_DIR}/prometheus"

mkdir -p "${PROM_DIR}"

# Prometheus main config
cat > "${PROM_DIR}/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  scrape_timeout: 10s
  evaluation_interval: 30s

  scrape_protocols:
    - OpenMetricsText1.0.0
    - OpenMetricsText0.0.1
    - PrometheusText1.0.0
    - PrometheusText0.0.4

  metric_name_validation_scheme: utf8
  metric_name_escaping_scheme: allow-utf-8

rule_files:
  - /etc/prometheus/rules.yml
  - /etc/prometheus/alerts.yml

scrape_configs:
  # Self
  - job_name: 'prometheus'
    honor_labels: true
    static_configs:
      - targets: ['localhost:9090']
        labels:
          service: 'prometheus'
          tier: 'monitoring'

  # Backend API
  - job_name: 'predictora-backend'
    metrics_path: /metrics
    scheme: http
    static_configs:
      - targets: ['predictora-backend:8000']
        labels:
          service: 'backend'
          tier: 'app'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance

  # Guardian / control-plane
  - job_name: 'guardian'
    metrics_path: /metrics
    static_configs:
      - targets: ['guardian:9000']
        labels:
          service: 'guardian'
          tier: 'control-plane'

  # Event ingestor
  - job_name: 'event-ingestor'
    metrics_path: /metrics
    static_configs:
      - targets: ['event-ingestor:9100']
        labels:
          service: 'event-ingestor'
          tier: 'ingest'

  # Revenue / payments engine
  - job_name: 'revenue-exporter'
    metrics_path: /metrics
    static_configs:
      - targets: ['revenue-exporter:9200']
        labels:
          service: 'revenue'
          tier: 'payments'

  # Node exporter
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          service: 'node'
          tier: 'infra'

  # cAdvisor
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          service: 'cadvisor'
          tier: 'infra'

  # Traefik / ingress
  - job_name: 'traefik'
    metrics_path: /metrics
    static_configs:
      - targets: ['traefik:8082']
        labels:
          service: 'traefik'
          tier: 'edge'

  # Loki
  - job_name: 'loki'
    metrics_path: /metrics
    static_configs:
      - targets: ['loki:3100']
        labels:
          service: 'loki'
          tier: 'logging'

  # Alertmanager
  - job_name: 'alertmanager'
    metrics_path: /metrics
    static_configs:
      - targets: ['alertmanager:9093']
        labels:
          service: 'alertmanager'
          tier: 'monitoring'
EOF

# Recording rules
cat > "${PROM_DIR}/rules.yml" << 'EOF'
groups:
  - name: backend_requests
    interval: 30s
    rules:
      - record: backend:request_rate_1m
        expr: rate(predictora_backend_request_count[1m])

      - record: backend:request_duration_p95_5m
        expr: histogram_quantile(0.95,
              sum by (le) (rate(predictora_backend_request_duration_seconds_bucket[5m])))

  - name: infra_cpu
    interval: 30s
    rules:
      - record: node:cpu_usage_1m
        expr: 100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])))

  - name: infra_memory
    interval: 30s
    rules:
      - record: node:memory_usage_ratio
        expr: 1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

  - name: container_health
    interval: 30s
    rules:
      - record: container:cpu_usage_1m
        expr: rate(container_cpu_usage_seconds_total[1m])

      - record: container:memory_usage_bytes
        expr: container_memory_usage_bytes
EOF

# Alerting rules
cat > "${PROM_DIR}/alerts.yml" << 'EOF'
groups:
  - name: backend_alerts
    rules:
      - alert: BackendHighErrorRate
        expr: rate(predictora_backend_request_errors_total[5m]) > 0.05
        for: 10m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "High backend error rate"
          description: "Backend error rate > 5% for 10m"

      - alert: BackendHighLatencyP95
        expr: backend:request_duration_p95_5m > 1.5
        for: 10m
        labels:
          severity: warning
          team: backend
        annotations:
          summary: "High backend latency (p95)"
          description: "p95 latency > 1.5s for 10m"

  - name: infra_alerts
    rules:
      - alert: NodeHighCPU
        expr: node:cpu_usage_1m > 85
        for: 10m
        labels:
          severity: warning
          team: infra
        annotations:
          summary: "High node CPU usage"
          description: "CPU usage > 85% for 10m"

      - alert: NodeHighMemory
        expr: node:memory_usage_ratio > 0.9
        for: 10m
        labels:
          severity: critical
          team: infra
        annotations:
          summary: "High node memory usage"
          description: "Memory usage > 90% for 10m"

      - alert: ContainerOOMRisk
        expr: container:memory_usage_bytes > 0.9 * container_spec_memory_limit_bytes
        for: 5m
        labels:
          severity: warning
          team: infra
        annotations:
          summary: "Container near memory limit"
          description: "Container memory > 90% of limit for 5m"

  - name: monitoring_alerts
    rules:
      - alert: PrometheusTSDBHighUsage
        expr: prometheus_tsdb_head_series > 500000
        for: 15m
        labels:
          severity: warning
          team: sre
        annotations:
          summary: "Prometheus TSDB high series count"
          description: "Head series > 500k for 15m"

      - alert: PrometheusTargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
          team: sre
        annotations:
          summary: "Prometheus target down"
          description: "Target {{ $labels.job }} / {{ $labels.instance }} is down for 5m"
EOF

echo "VS-grade monitoring config written to ${PROM_DIR}"
