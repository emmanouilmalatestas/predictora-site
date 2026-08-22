#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/home/deploy/predictoraai"
MON_DIR="$ROOT_DIR/monitoring"
TRAEFIK_YML="$MON_DIR/traefik/traefik.yml"

echo "[1] Backup current configs"
mkdir -p "$ROOT_DIR/_backup_$(date +%Y%m%d-%H%M%S)"
cp "$ROOT_DIR/docker-compose.yml" "$ROOT_DIR/_backup_$(date +%Y%m%d-%H%M%S"/root-compose.yml")" || true
cp "$MON_DIR/docker-compose.yml" "$ROOT_DIR/_backup_$(date +%Y%m%d-%H%M%S"/monitoring-compose.yml")" || true
cp "$TRAEFIK_YML" "$ROOT_DIR/_backup_$(date +%Y%m%d-%H%M%S"/traefik.yml")" || true

echo "[2] Write clean monitoring traefik.yml (Docker-only, no file provider)"
cat > "$TRAEFIK_YML" <<'EOF'
api:
  dashboard: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"
  traefik:
    address: ":8080"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "traefik"
    watch: true

certificatesResolvers:
  cf:
    acme:
      email: admin@predictoraai.com
      storage: /etc/traefik/acme.json
      dnsChallenge:
        provider: cloudflare
EOF

echo "[3] Restart monitoring stack (Traefik + Grafana + Prometheus + Loki)"
cd "$MON_DIR"
docker compose down --remove-orphans
docker compose up -d

echo "[4] Restart production stack (backend + admin + webhook + db)"
cd "$ROOT_DIR"
docker compose down --remove-orphans
docker compose up -d

echo "[5] Show Traefik logs (verify Docker provider + routers + ACME)"
docker logs traefik --tail 200

echo
echo "✅ Cleanup done."
echo "→ Check: curl -I https://api.predictoraai.com"
echo "→ If still SSL error, send me: docker logs traefik --tail 200"
