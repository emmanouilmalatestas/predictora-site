#!/bin/bash
set -e

echo "🔥 TRAEFIK AUTO-FIX STARTING..."

BASE_DIR="/home/deploy/predictoraai/traefik"
cd $BASE_DIR

echo "📌 Detecting all docker.sock files..."
SOCKETS=$(sudo find / -type s -name "docker.sock" 2>/dev/null)

echo "📌 Checking API versions for each socket..."
GOOD_SOCKET=""
BAD_SOCKET=""

for S in $SOCKETS; do
  echo "🔍 Testing socket: $S"
  if curl --unix-socket $S http://localhost/version 2>/dev/null | grep -q '"ApiVersion":"1.54"'; then
    echo "✅ Found GOOD socket: $S"
    GOOD_SOCKET=$S
  else
    echo "❌ Found BAD/OLD socket: $S"
    BAD_SOCKET=$S
  fi
done

if [ -z "$GOOD_SOCKET" ]; then
  echo "💀 ERROR: No valid Docker socket with API >= 1.40 found."
  exit 1
fi

echo "📌 Updating docker-compose.yml with correct socket..."
sed -i "s|/run/docker.sock|$GOOD_SOCKET|g" docker-compose.yml
sed -i "s|/var/run/docker.sock|$GOOD_SOCKET|g" docker-compose.yml

echo "📌 Restarting Traefik with correct socket..."
docker compose down || true
docker compose up -d

echo "⏳ Waiting 5 seconds..."
sleep 5

echo "📌 Checking Traefik routers..."
if docker logs traefik --tail=200 | grep -qi "router"; then
  echo "✅ Routers detected."
else
  echo "❌ No routers detected — something still wrong."
fi

echo "📌 Checking backend health..."
if curl -sk https://predictoraai.com/health | grep -q '"status"'; then
  echo "🎉 TRAEFIK AUTO-FIX COMPLETE — ROUTING OK"
else
  echo "⚠️ Traefik running but backend not reachable yet."
fi
