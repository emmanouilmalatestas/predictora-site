#!/bin/bash
set -e

echo ">>> Stopping Traefik..."
docker compose -p traefik3 down || true

echo ">>> Removing Traefik container..."
docker rm -f traefik 2>/dev/null || true

echo ">>> Removing ALL Traefik images safely..."
docker images --format '{{.Repository}} {{.ID}}' | grep -i traefik | awk '{print $2}' | while read -r IMG; do
  if [ -n "$IMG" ]; then
    echo "Removing image $IMG"
    docker rmi -f "$IMG" || true
  fi
done

echo ">>> Pulling Traefik v2.11.4..."
docker pull traefik:v2.11.4

echo ">>> Updating docker-compose.yml to use Traefik v2.11.4..."
sed -i 's|ghcr.io/traefik/traefik:v3.0|traefik:v2.11.4|g' docker-compose.yml
sed -i 's|traefik:v3.0|traefik:v2.11.4|g' docker-compose.yml

echo ">>> Ensuring correct docker.sock mount..."
sed -i 's|/var/run/docker.sock:/var/run/docker.sock|/run/docker.sock:/var/run/docker.sock|g' docker-compose.yml

echo ">>> Starting Traefik..."
docker compose -p traefik3 up -d --force-recreate

echo ">>> Tail logs..."
docker logs traefik --tail=200
