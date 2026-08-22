#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/deploy/predictoraai"
DYNAMIC="$ROOT/traefik/dynamic"
COMPOSE="$ROOT/docker-compose.yml"

echo "[*] Hardening Traefik…"

mkdir -p "$DYNAMIC"

###############################################
# 1. TLS OPTIONS (MODERN)
###############################################
cat > "$DYNAMIC/tls.yml" << 'EOF'
tls:
  options:
    modern:
      minVersion: VersionTLS12
      sniStrict: true
      cipherSuites:
        - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
        - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
EOF

###############################################
# 2. SECURITY HEADERS + RATE LIMIT
###############################################
cat > "$DYNAMIC/security.yml" << 'EOF'
http:
  middlewares:
    security-headers:
      headers:
        sslRedirect: true
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        contentTypeNosniff: true
        browserXssFilter: true
        frameDeny: true
        referrerPolicy: "strict-origin-when-cross-origin"
        permissionsPolicy: "geolocation=(), microphone=(), camera=()"
        customResponseHeaders:
          X-Content-Type-Options: "nosniff"
          X-Frame-Options: "DENY"
          X-XSS-Protection: "1; mode=block"

    api-ratelimit:
      rateLimit:
        average: 50
        burst: 100
EOF

###############################################
# 3. DASHBOARD HARDENING (AUTH + IP ALLOWLIST)
###############################################

BCRYPT='admin:$2y$05$rONnPVmDcVlTPhF9LSIdf.YlZ5oSqZNRC90E851ctNZmM9MI1cVFS'

cat > "$DYNAMIC/dashboard.yml" << EOF
http:
  middlewares:
    dashboard-auth:
      basicAuth:
        users:
          - "$BCRYPT"

    dashboard-allowlist:
      ipWhiteList:
        sourceRange:
          - "62.238.34.36/32"

  routers:
    traefik-dashboard:
      rule: "Host(\`traefik.predictoraai.com\`)"
      entryPoints:
        - websecure
      service: api@internal
      middlewares:
        - dashboard-auth
        - dashboard-allowlist
      tls:
        certResolver: letsencrypt
EOF

###############################################
# 4. PATCH docker-compose.yml (STATIC CONFIG)
###############################################

echo "[*] Patching docker-compose.yml…"

# Backup once
if [ ! -f "$COMPOSE.bak_hardened" ]; then
  cp "$COMPOSE" "$COMPOSE.bak_hardened"
fi

# Remove old command block
sed -i '/traefik:/,/image:/!b;/command:/,/^[^ ]/d' "$COMPOSE"

# Insert new hardened command block
sed -i '/traefik:/a \
    command:\n\
      - "--providers.docker=true"\n\
      - "--providers.docker.exposedbydefault=false"\n\
      - "--providers.file.directory=/etc/traefik/dynamic"\n\
      - "--providers.file.watch=true"\n\
      - "--entrypoints.web.address=:80"\n\
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"\n\
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"\n\
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"\n\
      - "--entrypoints.websecure.address=:443"\n\
      - "--entrypoints.websecure.http.tls=true"\n\
      - "--entrypoints.websecure.http.tls.certresolver=letsencrypt"\n\
      - "--entrypoints.websecure.http.tls.options=modern@file"\n\
      - "--entrypoints.traefik.address=:8080"\n\
      - "--api.dashboard=true"\n\
      - "--api.insecure=true"\n\
      - "--ping=true"\n\
      - "--ping.entrypoint=traefik"\n\
      - "--certificatesresolvers.letsencrypt.acme.email=admin@predictoraai.com"\n\
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"\n\
      - "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare"\n\
      - "--certificatesresolvers.letsencrypt.acme.dnschallenge.delaybeforecheck=0"\n\
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=false"\n\
      - "--log.level=INFO"' "$COMPOSE"

###############################################
# 5. RESTART STACK
###############################################

echo "[*] Restarting stack…"
cd "$ROOT"
docker compose down
docker compose up -d

echo "[✓] Hardened Traefik applied successfully."
