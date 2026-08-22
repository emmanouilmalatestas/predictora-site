#!/bin/bash
set -euo pipefail

echo "=== Running JWT module ==="
./modules/jwt/validate.sh
echo

echo "=== Running Traefik hardening module ==="
./modules/traefik/harden.sh
echo

echo "=== Running Stateless backend module ==="
./modules/backend/stateless_check.sh
echo

echo "=== All modules executed successfully ==="
