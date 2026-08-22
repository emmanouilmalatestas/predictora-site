#!/usr/bin/env bash
set -euo pipefail

echo "=== Guardian Health Worker ==="
echo "Time: $(date)"

# Node count
NODES=$(kubectl get nodes --no-headers | wc -l)
echo "Nodes: $NODES"

# Pod count
PODS=$(kubectl get pods -A --no-headers | wc -l)
echo "Pods: $PODS"

# Total restarts (sanitize)
RESTARTS=$(kubectl get pods -A --no-headers | awk '{print $4}' | grep -E '^[0-9]+$' | paste -sd+ - | bc || echo 0)
echo "Total restarts: $RESTARTS"

# Backend health (no backend service yet)
BACKEND_HEALTH=$(curl -s --max-time 2 http://predictora-backend:8000/health || echo FAIL)
echo "Backend health: $BACKEND_HEALTH"

# Traefik admin API (ClusterIP)
TA_RAW=$(curl -s --max-time 3 http://10.43.40.156:8080/api/rawdata || echo "")
TA_ROUTERS=$(echo "$TA_RAW" | jq '.routers | length' 2>/dev/null || echo "N/A")
echo "Traefik-admin routers: $TA_ROUTERS"

# Prometheus readiness (ClusterIP)
PROM_READY=$(curl -s --max-time 3 http://10.43.64.176:9090/-/ready || echo FAIL)
echo "Prometheus ready: $PROM_READY"

echo "=== Guardian Health Worker Completed ==="
