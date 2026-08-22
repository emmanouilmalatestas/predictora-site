#!/bin/bash
set -e

NAMESPACE="predictora"
DEPLOY="backend"

echo "=== PredictoraOS Full Power Activation ==="

echo "→ Enabling Observability Exporter..."
kubectl -n $NAMESPACE set env deployment/$DEPLOY \
  PREDICTORA_OBSERVABILITY_EXPORTER_ENABLED=true \
  PREDICTORA_EXPORTER_MODE=full \
  PREDICTORA_EXPORTER_INTERVAL=5s \
  PREDICTORA_EXPORTER_TARGET=prometheus

echo "→ Adding Observability Exporter sidecar..."
kubectl -n $NAMESPACE patch deployment $DEPLOY --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/-",
    "value": {
      "name": "predictora-observability-exporter",
      "image": "manolio/predictoraai-observability:prod",
      "imagePullPolicy": "Always",
      "env": [
        { "name": "PREDICTORA_EXPORTER_MODE", "value": "full" },
        { "name": "PREDICTORA_EXPORTER_INTERVAL", "value": "5s" },
        { "name": "PREDICTORA_EXPORTER_TARGET", "value": "prometheus" }
      ],
      "ports": [
        { "containerPort": 9100 }
      ]
    }
  }
]'

echo "→ Enabling Analytics Pipeline..."
kubectl -n $NAMESPACE set env deployment/$DEPLOY \
  PREDICTORA_ANALYTICS_PIPELINE_ENABLED=true \
  PREDICTORA_ANALYTICS_MODE=full \
  PREDICTORA_ANALYTICS_EXPORT_INTERVAL=10s

echo "→ Enabling Runtime Sharding..."
kubectl -n $NAMESPACE set env deployment/$DEPLOY \
  PREDICTORA_RUNTIME_SHARDING_ENABLED=true \
  PREDICTORA_SHARD_COUNT=3 \
  PREDICTORA_SHARD_STRATEGY=tenant-based

echo "→ Restarting backend deployment..."
kubectl -n $NAMESPACE rollout restart deployment/$DEPLOY

echo "→ Waiting for rollout..."
kubectl -n $NAMESPACE rollout status deployment/$DEPLOY

echo "=== PredictoraOS Full Power Mode Activated ==="
