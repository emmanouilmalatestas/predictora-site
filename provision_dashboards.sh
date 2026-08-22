#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY:-}"

if [ -z "$GRAFANA_API_KEY" ]; then
  echo "Set GRAFANA_API_KEY first"
  exit 1
fi

DASHBOARD_DIR="$(pwd)/dashboards"

if [ ! -d "$DASHBOARD_DIR" ]; then
  echo "Dashboards directory not found: $DASHBOARD_DIR"
  exit 1
fi

import_dashboard() {
  local file="$1"
  echo "📊 Importing: $file"

  # Validate JSON
  if ! jq empty "$file" >/dev/null 2>&1; then
    echo "❌ Invalid JSON in $file"
    exit 1
  fi

  # Build payload
  payload=$(jq -c '{dashboard: ., overwrite: true, folderId: 0}' "$file")

  # Import
  curl -sS -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -d "$payload" \
    "$GRAFANA_URL/api/dashboards/import" | jq .
}

echo "🚀 Starting Grafana dashboard provisioning..."
echo "📁 Directory: $DASHBOARD_DIR"
echo

# Loop through all JSON dashboards
for file in "$DASHBOARD_DIR"/*.json; do
  import_dashboard "$file"
  echo "----------------------------------------"
done

echo "✅ All dashboards imported successfully."
