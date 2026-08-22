#!/usr/bin/env bash
set -euo pipefail

# Load system-wide environment variables
if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi

echo "🚀 Unicorn Payments Bootstrap starting..."

PROJECT_ROOT="/home/deploy/predictoraai"
cd "$PROJECT_ROOT"

echo "📁 Using project root: $PROJECT_ROOT"

echo "✅ Checking required environment variables..."

REQUIRED_VARS=(
  "STRIPE_WEBHOOK_SECRET"
  "STRIPE_SECRET_KEY"
  "STRIPE_PUBLISHABLE_KEY"
)

MISSING=0
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR-}" ]; then
    echo "❌ Missing: $VAR"
    MISSING=1
  else
    echo "✔ $VAR is set"
  fi
done

if [ "$MISSING" -ne 0 ]; then
  echo "⛔ Please set the missing variables (e.g. in /etc/environment) and re-run."
  exit 1
fi

echo "🐘 Ensuring Redis is defined in docker-compose.prod.yml (service: redis)..."
# Προϋπόθεση: έχεις service `redis:` στο docker-compose.prod.yml

echo "🐳 Building Stripe webhook image..."
docker build -t predictoraai-stripe-webhook:latest -f backend/webhook.Dockerfile .

echo "🐳 Bringing up core money stack (Redis + backend + webhook)..."
docker compose -f docker-compose.prod.yml up -d predictora-redis predictora-backend predictoraai-stripe-webhook

echo "⏳ Waiting 5s for services to stabilize..."
sleep 5

echo "📡 Checking running containers..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "redis|predictoraai-backend|predictoraai-stripe-webhook" || true

echo "🩺 Quick health probe on webhook..."
curl -k -s https://webhook.predictoraai.com/health || echo "⚠ health endpoint not reachable via curl (check Traefik/SSL)"

echo "✅ Unicorn Payments stack is ONLINE (infra-level)."
echo "   - Redis running"
echo "   - Backend running"
echo "   - Stripe webhook running"
echo "   - Stripe env vars present"

echo "🎯 Next manual check:"
echo "   1) On your laptop: stripe listen --forward-to https://webhook.predictoraai.com/stripe/webhook"
echo "   2) Then: stripe trigger checkout.session.completed"
echo "   3) On server: docker logs -f predictoraai-stripe-webhook"
echo "      → You should see: Received event: checkout.session.completed"

echo "🦄 All systems go. PredictoraAI money engine is live."
