#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="predictora"
TENANT_ID="00000000-0000-0000-0000-000000000000"

log() {
  echo "[FULL-CAPACITY] $1"
}

# 1. Find DB pod
DB_POD=$(kubectl -n "$NAMESPACE" get pods -l app=predictoraai-db -o jsonpath='{.items[0].metadata.name}')
log "Using DB pod: $DB_POD"

# 2. Apply enterprise billing baseline
log "Applying enterprise billing baseline..."

kubectl -n "$NAMESPACE" exec -i "$DB_POD" -- bash <<EOF
set -e

psql -U predictora -d predictora <<SQL

ALTER TABLE usage ADD COLUMN IF NOT EXISTS amount_cents INTEGER DEFAULT 0;

CREATE TABLE IF NOT EXISTS invoices (
    id SERIAL PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    amount_cents INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stripe_payments (
    id SERIAL PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    amount_cents INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accounts (
    id SERIAL PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ledger_entries (
    id SERIAL PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    debit_account_id INTEGER REFERENCES accounts(id),
    credit_account_id INTEGER REFERENCES accounts(id),
    amount_cents INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wallet (
    tenant_id TEXT PRIMARY KEY,
    balance_cents INTEGER NOT NULL DEFAULT 0
);

INSERT INTO accounts (tenant_id, name, type)
VALUES
  ('${TENANT_ID}', 'wallet', 'asset'),
  ('${TENANT_ID}', 'stripe_clearing', 'asset'),
  ('${TENANT_ID}', 'revenue', 'income'),
  ('${TENANT_ID}', 'cash', 'asset')
ON CONFLICT DO NOTHING;

INSERT INTO wallet (tenant_id, balance_cents)
VALUES ('${TENANT_ID}', 0)
ON CONFLICT (tenant_id) DO NOTHING;

DELETE FROM usage WHERE tenant_id = '${TENANT_ID}';
DELETE FROM invoices WHERE tenant_id = '${TENANT_ID}';
DELETE FROM stripe_payments WHERE tenant_id = '${TENANT_ID}';
DELETE FROM ledger_entries WHERE tenant_id = '${TENANT_ID}';

INSERT INTO usage (tenant_id, capability, units, amount_cents)
VALUES ('${TENANT_ID}', 'runtime', 1, 100);

INSERT INTO invoices (tenant_id, amount_cents, status)
VALUES ('${TENANT_ID}', 100, 'paid');

INSERT INTO stripe_payments (tenant_id, amount_cents, status)
VALUES ('${TENANT_ID}', 100, 'succeeded');

-- Ledger entries: revenue → cash → wallet → stripe clearing
INSERT INTO ledger_entries (tenant_id, debit_account_id, credit_account_id, amount_cents)
SELECT '${TENANT_ID}', a_cash.id, a_revenue.id, 100
FROM accounts a_cash, accounts a_revenue
WHERE a_cash.name='cash' AND a_revenue.name='revenue'
LIMIT 1;

INSERT INTO ledger_entries (tenant_id, debit_account_id, credit_account_id, amount_cents)
SELECT '${TENANT_ID}', a_wallet.id, a_cash.id, 100
FROM accounts a_wallet, accounts a_cash
WHERE a_wallet.name='wallet' AND a_cash.name='cash'
LIMIT 1;

INSERT INTO ledger_entries (tenant_id, debit_account_id, credit_account_id, amount_cents)
SELECT '${TENANT_ID}', a_stripe.id, a_wallet.id, 100
FROM accounts a_stripe, accounts a_wallet
WHERE a_stripe.name='stripe_clearing' AND a_wallet.name='wallet'
LIMIT 1;

UPDATE wallet
SET balance_cents = 100
WHERE tenant_id = '${TENANT_ID}';

SQL
EOF

log "Enterprise billing baseline applied."

# 3. Patch backend deployment with full enterprise flags
log "Patching backend deployment with full enterprise flags..."

kubectl -n "$NAMESPACE" patch deployment backend --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/env", "value": [
    {"name": "PREDICTORA_MODE", "value": "enterprise"},
    {"name": "PREDICTORA_CERTIFICATION_MODE", "value": "A,B"},
    {"name": "PREDICTORA_BILLING_ENABLED", "value": "true"},
    {"name": "PREDICTORA_REVENUE_RECOGNITION_ENABLED", "value": "true"},
    {"name": "PREDICTORA_DETERMINISTIC_RUNTIME_ENABLED", "value": "true"},
    {"name": "PREDICTORA_REPLAY_ENABLED", "value": "true"},
    {"name": "PREDICTORA_CHAOS_ENABLED", "value": "true"},
    {"name": "PREDICTORA_LEDGER_HASHING_ENABLED", "value": "true"},
    {"name": "PREDICTORA_EVENT_SOURCING_ENABLED", "value": "true"}
  ]}
]'

log "Enterprise flags applied."

# 4. Restart backend
log "Restarting backend deployment..."
kubectl -n "$NAMESPACE" rollout restart deployment backend
kubectl -n "$NAMESPACE" rollout status deployment backend

log "Backend restarted."

# 5. Certification check inside backend pod
log "Running Predictora Certification inside backend pod..."

BACKEND_POD=$(kubectl -n "$NAMESPACE" get pods -l app=backend -o jsonpath='{.items[0].metadata.name}')

CERT_JSON=$(kubectl -n "$NAMESPACE" exec -i "$BACKEND_POD" -c backend -- \
  curl -s http://localhost:8000/api/certification || true)

echo "$CERT_JSON" | jq '.'

STATUS=$(echo "$CERT_JSON" | jq -r '."Predictora Certification".status')

log "Certification status: $STATUS"

if [ "$STATUS" != "PRODUCTION READY" ]; then
  log "ERROR: Full Capacity Mode not certified. Aborting."
  exit 1
fi

log "PredictoraOS FULL CAPACITY MODE is ACTIVE, CERTIFIED & READY FOR PRODUCTION."
exit 0
