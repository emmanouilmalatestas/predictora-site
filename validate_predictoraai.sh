#!/bin/bash

echo "=== 0) START FULL PROJECT VALIDATION ==="

echo "=== 1) CHECK CONTAINER HEALTH ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep predictoraai

echo "=== 2) VALIDATE POSTGRES ==="
docker exec -it predictoraai-db psql -U predictora -d predictora -c "SELECT 1;" || {
  echo "❌ Postgres failed"
  exit 1
}
docker exec -it predictoraai-db ls -la /var/lib/postgresql/data/pgdata

echo "=== 3) VALIDATE REDIS ==="
docker exec -it predictoraai-predictoraai-predictora-redis-1 redis-cli -a "N9p3q7L2x8R1v6K4t0M5g2H8n3B4c7" ping

echo "=== 4) VALIDATE BACKEND HEALTH ==="
curl -s https://api.predictoraai.com/health

echo "=== 5) VALIDATE FRONTEND ==="
curl -I https://predictoraai.com

echo "=== 6) VALIDATE ADMIN FRONTEND ==="
curl -I https://admin.predictoraai.com

echo "=== 7) VALIDATE STRIPE WEBHOOK ==="
curl -I https://webhook.predictoraai.com/stripe/webhook

echo "=== 8) VALIDATE EVENT INGESTOR ==="
curl -I https://api.predictoraai.com/events/test

echo "=== 9) VALIDATE GUARDIAN ==="
docker logs predictoraai-guardian-1 --tail 50

echo "=== 10) VALIDATE PROMETHEUS ==="
curl -I http://localhost:9090

echo "=== 11) VALIDATE LOKI ==="
curl -I http://localhost:3100/ready

echo "=== 12) VALIDATE NODE EXPORTER ==="
curl -I http://localhost:9115

echo "=== 13) VALIDATE BILLING SERVICE ==="
curl -I https://api.predictoraai.com/billing/status

echo "=== 14) VALIDATE TRAEFIK ROUTERS ==="
curl -I https://traefik.predictoraai.com

echo "=== FULL PROJECT VALIDATION COMPLETE ==="
