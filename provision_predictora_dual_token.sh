#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------
# ENVIRONMENT TOKENS
# -----------------------------------------
# ADMIN_API_KEY → Admin API Key (NOT service account)
# SERVICE_ACCOUNT_TOKEN → Token from provisioner service account

if [ -z "${ADMIN_API_KEY:-}" ]; then
  echo "❌ ADMIN_API_KEY is missing"
  exit 1
fi

if [ -z "${SERVICE_ACCOUNT_TOKEN:-}" ]; then
  echo "❌ SERVICE_ACCOUNT_TOKEN is missing"
  exit 1
fi

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"

# -----------------------------------------
# HELPERS
# -----------------------------------------

admin_post() {
  curl -sS -X POST \
    -H "Authorization: Bearer $ADMIN_API_KEY" \
    -H "Content-Type: application/json" \
    "$@"
}

admin_put() {
  curl -sS -X PUT \
    -H "Authorization: Bearer $ADMIN_API_KEY" \
    -H "Content-Type: application/json" \
    "$@"
}

sa_post() {
  curl -sS -X POST \
    -H "Authorization: Bearer $SERVICE_ACCOUNT_TOKEN" \
    -H "Content-Type: application/json" \
    "$@"
}

sa_put() {
  curl -sS -X PUT \
    -H "Authorization: Bearer $SERVICE_ACCOUNT_TOKEN" \
    -H "Content-Type: application/json" \
    "$@"
}

import_dashboard() {
  local name="$1"
  local json="$2"
  local folder_uid="$3"

  local tmp="/tmp/${name}.json"
  echo "$json" > "$tmp"

  echo "📊 Importing dashboard: $name → folder: $folder_uid"

  payload=$(jq -c --arg folder "$folder_uid" '{dashboard: ., overwrite: true, folderUid: $folder}' "$tmp")

  sa_post "$GRAFANA_URL/api/dashboards/import" -d "$payload" | jq .
  rm -f "$tmp"
}

# -----------------------------------------
# CREATE FOLDERS (ADMIN TOKEN)
# -----------------------------------------

echo "📁 Creating folders with ADMIN_API_KEY..."

admin_post "$GRAFANA_URL/api/folders" \
  -d '{"uid":"predictora_obs","title":"PredictoraAI - Observability"}' | jq .

admin_post "$GRAFANA_URL/api/folders" \
  -d '{"uid":"predictora_biz","title":"PredictoraAI - Business"}' | jq .

admin_post "$GRAFANA_URL/api/folders" \
  -d '{"uid":"predictora_slo","title":"PredictoraAI - SLO & Reliability"}' | jq .

# -----------------------------------------
# IMPORT DASHBOARDS (SERVICE ACCOUNT TOKEN)
# -----------------------------------------

import_dashboard "warzone_unified" '
{
  "title": "PredictoraAI WARZONE 9000 - Unified Observability",
  "schemaVersion": 39,
  "refresh": "10s",
  "panels": []
}
' "predictora_obs"

import_dashboard "api_scoring_engine" '
{
  "title": "PredictoraAI - API Scoring Engine",
  "schemaVersion": 39,
  "refresh": "10s",
  "panels": []
}
' "predictora_obs"

import_dashboard "business_kpis" '
{
  "title": "PredictoraAI - Business KPIs",
  "schemaVersion": 39,
  "refresh": "30s",
  "panels": []
}
' "predictora_biz"

import_dashboard "uptime_slo" '
{
  "title": "PredictoraAI - Uptime & SLO",
  "schemaVersion": 39,
  "refresh": "30s",
  "panels": []
}
' "predictora_slo"

# -----------------------------------------
# APPLY THEME (SERVICE ACCOUNT TOKEN)
# -----------------------------------------

echo "🎨 Applying PredictoraAI theme..."
sa_put "$GRAFANA_URL/api/user/preferences" \
  -d '{"theme":"dark"}' | jq .

# -----------------------------------------
# SET HOMEPAGE (ADMIN TOKEN)
# -----------------------------------------

echo "🏠 Setting PredictoraAI homepage..."
admin_put "$GRAFANA_URL/api/org/preferences" \
  -d '{"homeDashboardUID":"afozk2s90z08wa"}'

echo "🚀 PredictoraAI Dual‑Token Provisioning Complete."
