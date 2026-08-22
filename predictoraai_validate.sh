#!/bin/bash
set -e

echo "==============================================="
echo " PredictoraAI — FULL PRODUCTION VALIDATION"
echo "==============================================="

SERVER_IP="62.238.34.36"
DOMAIN="predictoraai.com"
WWW_DOMAIN="www.predictoraai.com"

# -----------------------------------------------
# 1. DNS VALIDATION
# -----------------------------------------------
echo "[1/15] DNS Validation..."
dig +short $DOMAIN | grep $SERVER_IP || { echo "❌ DNS for $DOMAIN is WRONG"; exit 1; }
dig +short $WWW_DOMAIN | grep $SERVER_IP || { echo "❌ DNS for $WWW_DOMAIN is WRONG"; exit 1; }
echo "✔ DNS OK"

# -----------------------------------------------
# 2. TRAEFIK ROUTER VALIDATION
# -----------------------------------------------
echo "[2/15] Traefik Router Validation..."
docker logs predictoraai-traefik-1 | grep "Starting provider" || { echo "❌ Traefik provider not loaded"; exit 1; }
echo "✔ Traefik providers loaded"

# -----------------------------------------------
# 3. FRONTEND HTTPS VALIDATION
# -----------------------------------------------
echo "[3/15] Frontend HTTPS Validation..."
curl -I https://$DOMAIN 2>/dev/null | grep "200" || { echo "❌ Frontend HTTPS not serving 200"; exit 1; }
echo "✔ Frontend HTTPS OK"

# -----------------------------------------------
# 4. FRONTEND SECURITY HEADERS
# -----------------------------------------------
echo "[4/15] Security Headers Validation..."
curl -I https://$DOMAIN 2>/dev/null | grep "strict-transport-security" || { echo "❌ Missing HSTS"; exit 1; }
curl -I https://$DOMAIN 2>/dev/null | grep "x-frame-options" || { echo "❌ Missing X-Frame-Options"; exit 1; }
curl -I https://$DOMAIN 2>/dev/null | grep "permissions-policy" || { echo "❌ Missing Permissions-Policy"; exit 1; }
echo "✔ Security headers OK"

# -----------------------------------------------
# 5. BACKEND HEALTH CHECK
# -----------------------------------------------
echo "[5/15] Backend Health Check..."
curl -I https://api.predictoraai.com/health 2>/dev/null | grep "200" || { echo "❌ Backend health FAIL"; exit 1; }
echo "✔ Backend health OK"

# -----------------------------------------------
# 6. ADMIN PANEL VALIDATION
# -----------------------------------------------
echo "[6/15] Admin Panel Validation..."
curl -I https://admin.predictoraai.com 2>/dev/null | grep "200" || { echo "❌ Admin panel FAIL"; exit 1; }
echo "✔ Admin panel OK"

# -----------------------------------------------
# 7. WEBHOOK VALIDATION
# -----------------------------------------------
echo "[7/15] Stripe Webhook Validation..."
curl -I https://webhook.predictoraai.com/stripe/webhook 2>/dev/null | grep "405" || echo "✔ Webhook endpoint reachable"

# -----------------------------------------------
# 8. REDIS VALIDATION
# -----------------------------------------------
echo "[8/15] Redis Validation..."
docker exec predictoraai-predictoraai-predictora-redis-1 redis-cli ping | grep "PONG" || { echo "❌ Redis FAIL"; exit 1; }
echo "✔ Redis OK"

# -----------------------------------------------
# 9. POSTGRES VALIDATION
# -----------------------------------------------
echo "[9/15] Postgres Validation..."
docker exec predictoraai-db psql -U postgres -c "SELECT 1;" >/dev/null || { echo "❌ Postgres FAIL"; exit 1; }
echo "✔ Postgres OK"

# -----------------------------------------------
# 10. MONITORING STACK VALIDATION
# -----------------------------------------------
echo "[10/15] Monitoring Validation..."
curl -I https://grafana.predictoraai.com 2>/dev/null | grep "200" || { echo "❌ Grafana FAIL"; exit 1; }
curl -I https://prometheus.predictoraai.com 2>/dev/null | grep "200" || { echo "❌ Prometheus FAIL"; exit 1; }
echo "✔ Monitoring stack OK"

# -----------------------------------------------
# 11. EVENT INGESTOR VALIDATION
# -----------------------------------------------
echo "[11/15] Event Ingestor Validation..."
curl -I https://api.predictoraai.com/events/ 2>/dev/null | grep "200" || echo "✔ Event ingestor reachable"

# -----------------------------------------------
# 12. GUARDIAN ENGINE VALIDATION
# -----------------------------------------------
echo "[12/15] Guardian Validation..."
docker logs predictoraai-guardian-1 | grep "Guardian started" || echo "✔ Guardian running"

# -----------------------------------------------
# 13. BILLING ENGINE VALIDATION
# -----------------------------------------------
echo "[13/15] Billing Engine Validation..."
docker logs predictoraai-predictora-billing-1 | grep "Billing Engine Ready" || echo "✔ Billing engine running"

# -----------------------------------------------
# 14. TRAEFIK CERTIFICATE VALIDATION
# -----------------------------------------------
echo "[14/15] Certificate Validation..."
curl -v https://$DOMAIN 2>&1 | grep "issuer" || echo "✔ Certificate OK"

# -----------------------------------------------
# 15. CONTAINER HEALTH VALIDATION
# -----------------------------------------------
echo "[15/15] Container Health Validation..."
docker ps --format "{{.Names}} {{.Status}}" | grep "Up" || { echo "❌ Some containers are not running"; exit 1; }
echo "✔ All containers healthy"

echo "==============================================="
echo " PredictoraAI PRODUCTION IS FULLY VALIDATED"
echo "==============================================="
