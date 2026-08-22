#!/bin/bash

set -e

echo "🚀 Activating PredictoraOS Certification Engine — MODE B"

CONFIG="/app/predictora_certification.json"

echo "{
  \"mode\": \"B\",
  \"active\": true,
  \"deterministic\": true,
  \"run_suites\": [
    \"financial_integrity\",
    \"billing_integrity\",
    \"ledger_integrity\",
    \"replay_integrity\",
    \"runtime_integrity\",
    \"chaos_integrity\",
    \"infrastructure_integrity\",
    \"security_compliance\",
    \"operations_readiness\"
  ]
}" > "$CONFIG"

echo "🔄 Restarting backend pods to apply Mode B..."
echo "⚠️ Reminder: kubectl is not available inside the container."
echo "⚠️ Please restart pods from the host."

echo "✅ Mode B JSON written successfully."
