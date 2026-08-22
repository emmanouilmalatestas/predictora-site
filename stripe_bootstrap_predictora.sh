#!/usr/bin/env bash
set -e

echo "[*] Using STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY:0:8}..."

PRODUCT_ID=$(stripe products create --name PredictoraAI --json | jq -r '.id')
echo "[+] Product: $PRODUCT_ID"

PRICE_ID=$(stripe prices create --product "$PRODUCT_ID" --currency eur --unit-amount 1 --recurring interval=month --json | jq -r '.id')
echo "[+] Price: $PRICE_ID"

METER_ID=$(stripe billing.meters create --display-name predictoraai_signals --event-name predictoraai_signals --aggregation sum --json | jq -r '.id')
echo "[+] Meter: $METER_ID"

stripe prices update "$PRICE_ID" --meter "$METER_ID" >/dev/null
echo "[+] Attached meter to price"

WEBHOOK_ID=$(stripe webhook_endpoints create --url "$WEBHOOK_URL" --enabled-events billing.meter_event.created --enabled-events customer.subscription.created --enabled-events customer.subscription.updated --enabled-events invoice.finalized --enabled-events invoice.payment_succeeded --enabled-events invoice.payment_failed --json | jq -r '.id')
echo "[+] Webhook endpoint: $WEBHOOK_ID"

echo
echo "=== OUTPUT ==="
echo "PRODUCT_ID=$PRODUCT_ID"
echo "PRICE_ID=$PRICE_ID"
echo "METER_ID=$METER_ID"
echo "WEBHOOK_ID=$WEBHOOK_ID"
