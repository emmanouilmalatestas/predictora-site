#!/bin/bash

# -----------------------------------------
# PredictoraAI Admin Control Plane Checker
# Production Macro Script
# -----------------------------------------

TOKEN_FILE="/home/deploy/predictoraai/admin_procedures/token.txt"

if [ ! -f "$TOKEN_FILE" ]; then
    echo "[ERROR] Token file not found: $TOKEN_FILE"
    exit 1
fi

TOKEN=$(cat $TOKEN_FILE)

echo "====================================="
echo " PredictoraAI Admin Control Checker"
echo "====================================="
echo
echo "[1] Active Sessions"
curl -s http://localhost:8000/admin/control/sessions/active \
  -H "Authorization: Bearer $TOKEN"
echo
echo

echo "[2] Activity Feed (Recent)"
curl -s http://localhost:8000/admin/control/activity/recent \
  -H "Authorization: Bearer $TOKEN"
echo
echo

echo "[3] Lockdown Status"
curl -s http://localhost:8000/admin/control/lockdown/status \
  -H "Authorization: Bearer $TOKEN"
echo
echo

echo "[4] Session Stats"
curl -s http://localhost:8000/admin/control/sessions/stats \
  -H "Authorization: Bearer $TOKEN"
echo
echo

echo "[DONE] All admin checks completed."
echo
