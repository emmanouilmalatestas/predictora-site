#!/bin/bash
set -e

echo ">>> Stopping Traefik..."
cd /home/deploy/predictoraai/traefik
docker compose -p traefik3 down || true

echo ">>> Stopping all containers..."
docker stop $(docker ps -q) 2>/dev/null || true

echo ">>> Removing old Docker packages..."
sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true

echo ">>> Adding official Docker repo (jammy override)..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ">>> Installing Docker 27.3.1..."
sudo apt-get update -y
sudo apt-get install -y \
  docker-ce=5:27.3.1-1~ubuntu.22.04~jammy \
  docker-ce-cli=5:27.3.1-1~ubuntu.22.04~jammy \
  containerd.io

echo ">>> Restarting Docker..."
sudo systemctl restart docker

echo ">>> Docker version now:"
docker version

echo ">>> Switching Traefik to v3.0..."
cd /home/deploy/predictoraai/traefik
sed -i 's|traefik:v2.11.4|ghcr.io/traefik/traefik:v3.0|g' docker-compose.yml
sed -i 's|traefik:v2.11|ghcr.io/traefik/traefik:v3.0|g' docker-compose.yml

echo ">>> Ensuring correct docker.sock mount..."
sed -i 's|/var/run/docker.sock:/var/run/docker.sock|/run/docker.sock:/var/run/docker.sock|g' docker-compose.yml

echo ">>> Pulling Traefik v3.0..."
docker pull ghcr.io/traefik/traefik:v3.0

echo ">>> Starting Traefik..."
docker compose -p traefik3 up -d --force-recreate

echo ">>> Tail logs:"
docker logs traefik --tail=200
