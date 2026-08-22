#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/deploy/predictoraai"
ENV_WEBHOOK="$ROOT/.env.prod"
ENV_BILLING="$ROOT/backend.env"
BILLING_CONTAINER="predictora-billing"
WEBHOOK_SERVICE="predictoraai-stripe-webhook"
BILLING_SERVICE="predictora-billing"
HEALTHCHECK_SCRIPT="stripe-healthcheck-v2.py"

echo ""
echo "=== STRIPE SYNC (LIVE) ==="
echo ""

read -r -p "Enter LIVE secret key (sk_live_...): " LIVE_KEY
read -r -p "Enter webhook signing secret (whsec_...): " WHSEC

if [[ -z "$LIVE_KEY" || -z "$WHSEC" ]]; then
  echo "ERROR: LIVE_KEY and WHSEC are required."
  exit 1
fi

echo ""
echo "Updating $ENV_WEBHOOK ..."
sed -i "s/^STRIPE_SECRET_KEY=.*/STRIPE_SECRET_KEY=$LIVE_KEY/" "$ENV_WEBHOOK" || \
  echo "STRIPE_SECRET_KEY=$LIVE_KEY" >> "$ENV_WEBHOOK"

sed -i "s/^STRIPE_WEBHOOK_SECRET=.*/STRIPE_WEBHOOK_SECRET=$WHSEC/" "$ENV_WEBHOOK" || \
  echo "STRIPE_WEBHOOK_SECRET=$WHSEC" >> "$ENV_WEBHOOK"

echo "Updating $ENV_BILLING ..."
sed -i "s/^STRIPE_LIVE_KEY=.*/STRIPE_LIVE_KEY=$LIVE_KEY/" "$ENV_BILLING" || \
  echo "STRIPE_LIVE_KEY=$LIVE_KEY" >> "$ENV_BILLING"

sed -i "s/^STRIPE_LIVE_WEBHOOK_SECRET=.*/STRIPE_LIVE_WEBHOOK_SECRET=$WHSEC/" "$ENV_BILLING" || \
  echo "STRIPE_LIVE_WEBHOOK_SECRET=$WHSEC" >> "$ENV_BILLING"

echo ""
echo "Rebuilding webhook + billing services..."
cd "$ROOT"
docker compose -f docker-compose.prod.yml up -d --build "$WEBHOOK_SERVICE" "$BILLING_SERVICE"

echo ""
echo "Copying healthcheck script into billing container..."
docker cp "$HEALTHCHECK_SCRIPT" "$BILLING_CONTAINER:/app/$HEALTHCHECK_SCRIPT"

echo ""
echo "Running Stripe healthcheck v2..."
docker exec -it "$BILLING_CONTAINER" python3 "/app/$HEALTHCHECK_SCRIPT"

echo ""
echo "=== STRIPE SYNC + HEALTHCHECK COMPLETED ✅ ==="
