#!/bin/bash

BACKEND_URL="http://localhost:8000"

ADMIN_USER="admin@predictora.ai"
ADMIN_PASS="PredictoraAdmin123!"

echo "====================================="
echo " PredictoraAI - Admin Control Plane"
echo " FULL MACRO RUN (NO JQ VERSION)"
echo "====================================="
echo

echo "[1] Admin login → get TOKEN + SESSION_ID"
LOGIN_RESPONSE=$(curl -s -X POST "$BACKEND_URL/admin/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}&password=${ADMIN_PASS}")

echo "LOGIN RESPONSE RAW:"
echo "$LOGIN_RESPONSE"
echo

# -----------------------------
# PURE BASH JSON PARSING
# -----------------------------
TOKEN=$(echo "$LOGIN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
SESSION_ID=$(echo "$LOGIN_RESPONSE" | sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then
  echo "[ERROR] Failed to extract token. Aborting."
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

echo "[OK] TOKEN ACQUIRED"
echo "TOKEN: $TOKEN"
echo "SESSION_ID: $SESSION_ID"
echo

echo "-------------------------------------"
echo "[2] Admin panel"
curl -s "$BACKEND_URL/admin/panel" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[3] Admin users"
curl -s "$BACKEND_URL/admin/users" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[4] Active sessions"
curl -s "$BACKEND_URL/admin/control/sessions/active" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[5] Session stats"
curl -s "$BACKEND_URL/admin/control/sessions/stats" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[6] Recent activity"
curl -s "$BACKEND_URL/admin/control/activity/recent" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[7] Lockdown status (before)"
curl -s "$BACKEND_URL/admin/control/lockdown/status" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[8] Lockdown ENABLE"
curl -s -X POST "$BACKEND_URL/admin/control/lockdown/enable" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[9] Lockdown DISABLE"
curl -s -X POST "$BACKEND_URL/admin/control/lockdown/disable" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[10] Purge all sessions"
curl -s -X DELETE "$BACKEND_URL/admin/control/sessions/purge" -H "$AUTH_HEADER"
echo
echo

echo "-------------------------------------"
echo "[11] Force logout current session"
if [ -n "$SESSION_ID" ]; then
  curl -s -X DELETE "$BACKEND_URL/admin/control/sessions/force/$SESSION_ID" -H "$AUTH_HEADER"
  echo
else
  echo "No valid SESSION_ID to force logout."
fi
echo
echo

echo "-------------------------------------"
echo "[12] Admin logout"
curl -s -X POST "$BACKEND_URL/admin/logout" -H "$AUTH_HEADER"
echo
echo

echo "====================================="
echo " FULL ADMIN CONTROL PLANE MACRO DONE"
echo "====================================="
echo
