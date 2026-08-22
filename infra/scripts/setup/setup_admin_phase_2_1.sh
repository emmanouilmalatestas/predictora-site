#!/usr/bin/env bash
set -euo pipefail

ADMIN_FE="/home/deploy/predictoraai/admin-frontend/app"

echo "[+] Adding Control Plane Navigation"
cat > "$ADMIN_FE/nav.tsx" << 'EOF'
"use client";
import Link from "next/link";

export default function Nav() {
  return (
    <div style={{
      display: "flex",
      gap: 20,
      padding: "16px 24px",
      background: "#0f172a",
      borderBottom: "1px solid #1e293b",
      position: "sticky",
      top: 0,
      zIndex: 50
    }}>
      <Link href="/panel">Panel</Link>
      <Link href="/sessions">Sessions</Link>
      <Link href="/activity">Activity</Link>
      <Link href="/api-keys">API Keys</Link>
      <Link href="/logout">Logout</Link>
    </div>
  );
}
EOF

echo "[+] Adding Admin Panel Page"
mkdir -p "$ADMIN_FE/panel"
cat > "$ADMIN_FE/panel/page.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";

export default function Panel() {
  const [data, setData] = useState<any>(null);
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;

  useEffect(() => {
    if (!token) return;
    axios.get("https://api.predictoraai.com/admin/panel", {
      headers: { Authorization: `Bearer ${token}` }
    }).then(res => setData(res.data));
  }, [token]);

  return (
    <>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Admin Panel</h1>
        <pre>{JSON.stringify(data, null, 2)}</pre>
      </div>
    </>
  );
}
EOF

echo "[+] Adding Sessions Page"
mkdir -p "$ADMIN_FE/sessions"
cat > "$ADMIN_FE/sessions/page.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";

export default function Sessions() {
  const [sessions, setSessions] = useState<any[]>([]);
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;

  useEffect(() => {
    if (!token) return;
    axios.get("https://api.predictoraai.com/admin/sessions", {
      headers: { Authorization: `Bearer ${token}` }
    }).then(res => setSessions(res.data.sessions || []));
  }, [token]);

  return (
    <>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Active Sessions</h1>
        <pre>{JSON.stringify(sessions, null, 2)}</pre>
      </div>
    </>
  );
}
EOF

echo "[+] Adding Activity Page"
mkdir -p "$ADMIN_FE/activity"
cat > "$ADMIN_FE/activity/page.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";

export default function Activity() {
  const [events, setEvents] = useState<any[]>([]);
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;

  useEffect(() => {
    if (!token) return;
    axios.get("https://api.predictoraai.com/admin/activity", {
      headers: { Authorization: `Bearer ${token}` }
    }).then(res => setEvents(res.data.events || []));
  }, [token]);

  return (
    <>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Activity Feed</h1>
        <pre>{JSON.stringify(events, null, 2)}</pre>
      </div>
    </>
  );
}
EOF

echo "[+] Adding API Keys Page (skeleton)"
mkdir -p "$ADMIN_FE/api-keys"
cat > "$ADMIN_FE/api-keys/page.tsx" << 'EOF'
"use client";
import React from "react";
import Nav from "../nav";

export default function ApiKeys() {
  return (
    <>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>API Keys</h1>
        <p>Phase 2.2 will add full API key management.</p>
      </div>
    </>
  );
}
EOF

echo "[+] Adding Logout Page"
mkdir -p "$ADMIN_FE/logout"
cat > "$ADMIN_FE/logout/page.tsx" << 'EOF'
"use client";
import { useEffect } from "react";
import axios from "axios";

export default function Logout() {
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;

  useEffect(() => {
    if (token) {
      axios.post("https://api.predictoraai.com/admin/logout", {}, {
        headers: { Authorization: `Bearer ${token}` }
      });
    }
    localStorage.removeItem("admin_token");
    window.location.href = "/";
  }, [token]);

  return <p>Logging out...</p>;
}
EOF

echo "[+] Rebuilding admin-frontend"
cd /home/deploy/predictoraai
docker compose build admin-frontend --no-cache
docker compose up -d

echo "[+] PHASE 2.1 COMPLETE — Sessions, Activity, Logout, API Keys UI added."
