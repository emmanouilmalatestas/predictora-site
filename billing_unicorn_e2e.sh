#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# Unicorn-grade Billing E2E Script
# ----------------------------------------

BILLING_HOST="https://api.predictoraai.com"
BILLING_HEALTH_ENDPOINT="$BILLING_HOST/billing/health"
BILLING_EVENTS_ENDPOINT="$BILLING_HOST/billing/events"

# Προαιρετικά: DB params για Postgres ledger check
# Ρύθμισέ τα αν θες DB verification
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-predictora}"
PGDATABASE="${PGDATABASE:-predictora}"
PGPASSWORD="${PGPASSWORD:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
  echo -e "${YELLOW}[*]${NC} $1"
}

ok() {
  echo -e "${GREEN}[OK]${NC} $1"
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  exit 1
}

# ----------------------------------------
# Step 1: Health check
# ----------------------------------------

log "Step 1: Checking billing health at: $BILLING_HEALTH_ENDPOINT"

HEALTH_STATUS=$(curl -s -o /tmp/billing_health.json -w "%{http_code}" "$BILLING_HEALTH_ENDPOINT" || echo "000")

if [ "$HEALTH_STATUS" != "200" ]; then
  fail "Health endpoint returned HTTP $HEALTH_STATUS"
fi

if ! grep -q '"status":"ok"' /tmp/billing_health.json; then
  fail "Health response does not contain status=ok"
fi

ok "Billing health endpoint is healthy."

# ----------------------------------------
# Step 2: Send unicorn-grade usage event
# ----------------------------------------

log "Step 2: Sending usage event to $BILLING_EVENTS_ENDPOINT"

EVENT_ID="evt_test_$(date +%s)"
IDEMPOTENCY_KEY="idemp_${EVENT_ID}"

# Decimal-style unit cost (string) – server πρέπει να το χειριστεί ως Decimal
UNIT_COST="0.002"
QUANTITY="10"

cat > /tmp/billing_usage_event.json <<EOF
{
  "event_id": "$EVENT_ID",
  "subscription_id": "00000000-0000-0000-0000-000000000001",
  "meter_name": "tokens",
  "quantity": $QUANTITY,
  "unit_cost_snapshot": "$UNIT_COST",
  "idempotency_key": "$IDEMPOTENCY_KEY",
  "source": "e2e_test",
  "metadata": {
    "test": true,
    "description": "unicorn_e2e_usage_event"
  }
}
EOF

USAGE_STATUS=$(curl -s -o /tmp/billing_usage_response.json -w "%{http_code}" \
  -X POST "$BILLING_EVENTS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d @/tmp/billing_usage_event.json || echo "000")

if [ "$USAGE_STATUS" != "200" ] && [ "$USAGE_STATUS" != "202" ]; then
  fail "Usage events endpoint returned HTTP $USAGE_STATUS"
fi

ok "Usage event accepted (HTTP $USAGE_STATUS)."

# ----------------------------------------
# Step 3: Idempotency check (replay same event)
# ----------------------------------------

log "Step 3: Replaying same usage event to verify idempotency (no double charge)."

USAGE_STATUS_REPLAY=$(curl -s -o /tmp/billing_usage_replay_response.json -w "%{http_code}" \
  -X POST "$BILLING_EVENTS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d @/tmp/billing_usage_event.json || echo "000")

if [ "$USAGE_STATUS_REPLAY" != "200" ] && [ "$USAGE_STATUS_REPLAY" != "202" ]; then
  fail "Replay usage event returned HTTP $USAGE_STATUS_REPLAY"
fi

ok "Replay accepted (HTTP $USAGE_STATUS_REPLAY). Server should treat it idempotently."

# ----------------------------------------
# Step 4: Optional – check ledger entry in Postgres
# ----------------------------------------

if command -v psql >/dev/null 2>&1; then
  log "Step 4: Checking ledger for idempotency_key: $IDEMPOTENCY_KEY"

  export PGPASSWORD

  COUNT=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t -A <<EOF || echo "0"
SELECT COUNT(*) FROM billing_ledger WHERE idempotency_key = '$IDEMPOTENCY_KEY';
EOF
)

  if [ "$COUNT" = "0" ]; then
    fail "No ledger entry found for idempotency_key=$IDEMPOTENCY_KEY"
  fi

  if [ "$COUNT" != "1" ]; then
    fail "Expected exactly 1 ledger entry for idempotency_key=$IDEMPOTENCY_KEY, found $COUNT (idempotency broken)."
  fi

  ok "Ledger has exactly 1 entry for idempotency_key=$IDEMPOTENCY_KEY (idempotency OK)."
else
  log "psql not found, skipping DB ledger verification step."
fi

ok "Unicorn-grade billing E2E test completed successfully."
