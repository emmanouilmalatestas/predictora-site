#!/bin/bash
set -euo pipefail

SECRET_FILE="/home/deploy/.secrets/predictoraai.env"
KEY="PREDICTORAAI_JWT_SECRET"

if ! grep -q "^${KEY}=" "$SECRET_FILE"; then
  echo "[JWT] ERROR: ${KEY} not found in ${SECRET_FILE}"
  exit 1
fi

SECRET_VALUE=$(grep "^${KEY}=" "$SECRET_FILE" | cut -d '=' -f2-)

if [ -z "$SECRET_VALUE" ]; then
  echo "[JWT] ERROR: ${KEY} is empty"
  exit 1
fi

if [ "${#SECRET_VALUE}" -lt 32 ]; then
  echo "[JWT] WARNING: ${KEY} length < 32 chars (weak secret)"
fi

echo "[JWT] OK: ${KEY} loaded (len=${#SECRET_VALUE})"
