#!/bin/bash
set -euo pipefail

DYNAMIC_FILE="./traefik_dynamic.yml"

if [ ! -f "$DYNAMIC_FILE" ]; then
  echo "[TRAEFIK] ERROR: ${DYNAMIC_FILE} not found"
  exit 1
fi

echo "[TRAEFIK] Applying security hardening to ${DYNAMIC_FILE}"

cat << 'EOF' >> "$DYNAMIC_FILE"

tls:
  options:
    default:
      minVersion: VersionTLS12
      sniStrict: true

http:
  middlewares:
    security-headers:
      headers:
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        frameDeny: true
        contentTypeNosniff: true
        browserXssFilter: true
EOF

echo "[TRAEFIK] Hardening appended"
