#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/deploy/predictoraai"
ADMIN_FE_DIR="$PROJECT_ROOT/admin-frontend"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

echo "[+] Project root: $PROJECT_ROOT"

mkdir -p "$ADMIN_FE_DIR"
cd "$ADMIN_FE_DIR"

echo "[+] Creating minimal Next.js admin frontend (manual scaffold)"

cat > package.json << 'EOF'
{
  "name": "predictoraai-admin-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "14.2.3",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "axios": "1.6.8"
  }
}
EOF

cat > next.config.mjs << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true
};

export default nextConfig;
EOF

mkdir -p app
cat > app/layout.tsx << 'EOF'
import React from "react";

export const metadata = {
  title: "PredictoraAI Admin",
  description: "Admin Control Plane"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: "system-ui, sans-serif", background: "#050816", color: "#e5e7eb" }}>
        {children}
      </body>
    </html>
  );
}
EOF

cat > app/page.tsx << 'EOF'
"use client";

import React, { useState } from "react";
import axios from "axios";

export default function LoginPage() {
  const [email, setEmail] = useState("admin@predictora.ai");
  const [password, setPassword] = useState("PredictoraAdmin123!");
  const [loading, setLoading] = useState(false);
  const [token, setToken] = useState<string | null>(null);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams();
      params.append("username", email);
      params.append("password", password);

      const res = await axios.post(
        "https://api.predictoraai.com/admin/login",
        params,
        {
          headers: {
            "Content-Type": "application/x-www-form-urlencoded"
          }
        }
      );

      setToken(res.data.access_token);
      setSessionId(res.data.session_id);
    } catch (err: any) {
      console.error(err);
      setError("Login failed");
    } finally {
      setLoading(false);
    }
  };

  const handleOpenPanel = async () => {
    if (!token) return;
    try {
      const res = await axios.get("https://api.predictoraai.com/admin/panel", {
        headers: {
          Authorization: `Bearer ${token}`
        }
      });
      alert("Admin Panel OK: " + JSON.stringify(res.data));
    } catch (err: any) {
      console.error(err);
      alert("Failed to load panel");
    }
  };

  return (
    <div style={{ display: "flex", minHeight: "100vh", alignItems: "center", justifyContent: "center" }}>
      <div style={{ width: 420, padding: 32, borderRadius: 16, background: "#0b1120", boxShadow: "0 0 40px rgba(0,0,0,0.6)" }}>
        <h1 style={{ fontSize: 24, marginBottom: 8 }}>PredictoraAI Admin</h1>
        <p style={{ fontSize: 14, color: "#9ca3af", marginBottom: 24 }}>
          WARZONE Control Plane — Login
        </p>

        <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <label style={{ fontSize: 13 }}>
            Email
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              style={{
                width: "100%",
                marginTop: 4,
                padding: "8px 10px",
                borderRadius: 8,
                border: "1px solid #1f2937",
                background: "#020617",
                color: "#e5e7eb"
              }}
            />
          </label>

          <label style={{ fontSize: 13 }}>
            Password
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              style={{
                width: "100%",
                marginTop: 4,
                padding: "8px 10px",
                borderRadius: 8,
                border: "1px solid #1f2937",
                background: "#020617",
                color: "#e5e7eb"
              }}
            />
          </label>

          <button
            type="submit"
            disabled={loading}
            style={{
              marginTop: 8,
              padding: "10px 12px",
              borderRadius: 8,
              border: "none",
              background: loading ? "#4b5563" : "#22c55e",
              color: "#020617",
              fontWeight: 600,
              cursor: loading ? "default" : "pointer"
            }}
          >
            {loading ? "Logging in..." : "Login"}
          </button>
        </form>

        {error && (
          <p style={{ marginTop: 12, fontSize: 13, color: "#f97316" }}>
            {error}
          </p>
        )}

        {token && (
          <div style={{ marginTop: 20, padding: 12, borderRadius: 8, background: "#020617", fontSize: 12 }}>
            <div style={{ marginBottom: 8 }}>
              <strong>Session ID:</strong> {sessionId}
            </div>
            <div style={{ wordBreak: "break-all" }}>
              <strong>Token:</strong> {token}
            </div>
            <button
              onClick={handleOpenPanel}
              style={{
                marginTop: 10,
                padding: "8px 10px",
                borderRadius: 8,
                border: "1px solid #22c55e",
                background: "transparent",
                color: "#22c55e",
                fontSize: 12,
                cursor: "pointer"
              }}
            >
              Test Admin Panel
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
EOF

cat > Dockerfile << 'EOF'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app ./
EXPOSE 3000
CMD ["npm", "run", "start"]
EOF

echo "[+] Admin frontend scaffolded at $ADMIN_FE_DIR"

########################################
# Patch docker-compose.yml
########################################

cd "$PROJECT_ROOT"

if grep -q "admin-frontend" "$COMPOSE_FILE"; then
  echo "[!] admin-frontend service already exists in docker-compose.yml, skipping patch"
else
  echo "[+] Patching docker-compose.yml with admin-frontend service"

  cat >> "$COMPOSE_FILE" << 'EOF'

  admin-frontend:
    build:
      context: ./admin-frontend
      dockerfile: Dockerfile
    image: predictoraai-admin-frontend:latest
    container_name: predictoraai-admin-frontend
    environment:
      - NODE_ENV=production
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=backend_internal"
      - "traefik.http.routers.admin-frontend.rule=Host(`admin.predictoraai.com`)"
      - "traefik.http.routers.admin-frontend.entrypoints=websecure"
      - "traefik.http.routers.admin-frontend.tls.certresolver=myresolver"
      - "traefik.http.services.admin-frontend.loadbalancer.server.port=3000"
    networks:
      - backend_internal
    restart: unless-stopped
EOF

fi

echo "[+] Rebuilding stack with admin-frontend"

docker compose build --no-cache
docker compose up -d

echo "[+] DONE. Open: https://admin.predictoraai.com"
