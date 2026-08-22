#!/bin/bash

echo "=== 1) STOP BILLING ENGINE ==="
docker stop predictora-billing || true
docker rm predictora-billing || true

echo "=== 2) REBUILD BILLING ENGINE ==="
cd /home/deploy/predictoraai
docker compose -f docker-compose.prod.yml build --no-cache predictora-billing

echo "=== 3) START BILLING ENGINE ==="
docker compose -f docker-compose.prod.yml up -d predictora-billing

echo "=== 4) WAIT FOR STARTUP ==="
sleep 4
docker logs predictora-billing --tail=50

echo "=== 5) TEST /status ==="
curl -s http://localhost:8010/status | jq

echo "=== 6) TEST USAGE INGESTION ==="
curl -s -X POST http://localhost:8010/usage \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"cus_test_123","meter_name":"predictora.tokens","value":42}' | jq

echo "=== 7) CHECK REDIS QUEUE LENGTH ==="
docker exec predictoraai-predictora-redis-1 redis-cli llen usage_events

echo "=== 8) TRIGGER STRIPE WEBHOOKS ==="
stripe trigger customer.subscription.updated
stripe trigger invoice.paid
stripe trigger checkout.session.completed

echo "=== 9) CHECK BILLING LOGS ==="
docker logs predictora-billing --tail=200

echo "=== 10) CHECK ADMIN ENDPOINTS ==="
curl -s http://localhost:8010/admin/subscriptions | jq
curl -s http://localhost:8010/admin/invoices | jq

echo "=== 11) DONE ==="
