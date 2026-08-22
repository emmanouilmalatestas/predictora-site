#!/usr/bin/env bash
set -euo pipefail

ADMIN_FE="/home/deploy/predictoraai/admin-frontend/app"

echo "[+] Adding ProtectedRoute wrapper"
cat > "$ADMIN_FE/protected.tsx" << 'EOF'
"use client";
import { useEffect } from "react";

export default function Protected({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    const token = localStorage.getItem("admin_token");
    if (!token) {
      window.location.href = "/";
    }
  }, []);

  return <>{children}</>;
}
EOF

echo "[+] Updating Panel to use ProtectedRoute"
cat > "$ADMIN_FE/panel/page.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";
import Protected from "../protected";

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
    <Protected>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Admin Panel</h1>
        <pre>{JSON.stringify(data, null, 2)}</pre>
      </div>
    </Protected>
  );
}
EOF

echo "[+] Adding Session Revoke UI"
cat > "$ADMIN_FE/sessions/page.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";
import Protected from "../protected";

export default function Sessions() {
  const [sessions, setSessions] = useState<any[]>([]);
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;

  const load = () => {
    axios.get("https://api.predictoraai.com/admin/sessions", {
      headers: { Authorization: `Bearer ${token}` }
    }).then(res => setSessions(res.data.sessions || []));
  };

  const revoke = (sessionId: string) => {
    axios.post("https://api.predictoraai.com/admin/sessions/revoke", 
      { session_id: sessionId },
      { headers: { Authorization: `Bearer ${token}` } }
    ).then(() => load());
  };

  useEffect(() => { if (token) load(); }, [token]);

  return (
    <Protected>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Active Sessions</h1>
        {sessions.map((s, i) => (
          <div key={i} style={{ marginBottom: 12, padding: 12, background: "#0f172a", borderRadius: 8 }}>
            <pre>{JSON.stringify(s, null, 2)}</pre>
            <button
              onClick={() => revoke(s.session_id)}
              style={{
                marginTop: 8,
                padding: "6px 10px",
                borderRadius: 6,
                border: "1px solid #ef4444",
                background: "transparent",
                color: "#ef4444",
                cursor: "pointer"
              }}
            >
              Revoke Session
            </button>
          </div>
        ))}
      </div>
    </Protected>
  );
}
EOF

echo "[+] Adding Lockdown Mode UI"
mkdir -p "$ADMIN_FE/lockdown"
cat > "$ADMIN_FE/lockdown/page.tsx" << 'EOF'
"use client";
import React, { useState, useEffect } from "react";
import axios from "axios";
import Nav from "../nav";
import Protected from "../protected";

export default function Lockdown() {
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;
  const [status, setStatus] = useState("unknown");

  const load = () => {
    axios.get("https://api.predictoraai.com/admin/lockdown/status", {
      headers: { Authorization: `Bearer ${token}` }
    }).then(res => setStatus(res.data.status));
  };

  const toggle = () => {
    axios.post("https://api.predictoraai.com/admin/lockdown/toggle", {}, {
      headers: { Authorization: `Bearer ${token}` }
    }).then(() => load());
  };

  useEffect(() => { if (token) load(); }, [token]);

  return (
    <Protected>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Lockdown Mode</h1>
        <p>Status: <strong>{status}</strong></p>
        <button
          onClick={toggle}
          style={{
            marginTop: 12,
            padding: "8px 12px",
            borderRadius: 8,
            border: "1px solid #fbbf24",
            background: "transparent",
            color: "#fbbf24",
            cursor: "pointer"
          }}
        >
          Toggle Lockdown
        </button>
      </div>
    </Protected>
  );
}
EOF

echo "[+] Adding API Key Manager UI"
cat > "$ADMIN_FE/api-keys/page.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";
import Protected from "../protected";

export default function ApiKeys() {
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;
  const [keys, setKeys] = useState<any[]>([]);
  const [owner, setOwner] = useState("");

  const load = () => {
    axios.get("https://api.predictoraai.com/admin/api-keys", {
      headers: { Authorization: `Bearer ${token}` }
    }).then(res => setKeys(res.data.keys || []));
  };

  const createKey = () => {
    axios.post("https://api.predictoraai.com/admin/api-keys/create",
      { owner },
      { headers: { Authorization: `Bearer ${token}` } }
    ).then(() => load());
  };

  const revoke = (id: number) => {
    axios.post("https://api.predictoraai.com/admin/api-keys/revoke",
      { id },
      { headers: { Authorization: `Bearer ${token}` } }
    ).then(() => load());
  };

  useEffect(() => { if (token) load(); }, [token]);

  return (
    <Protected>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>API Keys</h1>

        <div style={{ marginBottom: 20 }}>
          <input
            placeholder="Owner email"
            value={owner}
            onChange={e => setOwner(e.target.value)}
            style={{
              padding: "8px 10px",
              borderRadius: 8,
              border: "1px solid #1e293b",
              background: "#020617",
              color: "#e5e7eb",
              marginRight: 8
            }}
          />
          <button
            onClick={createKey}
            style={{
              padding: "8px 12px",
              borderRadius: 8,
              border: "1px solid #22c55e",
              background: "transparent",
              color: "#22c55e",
              cursor: "pointer"
            }}
          >
            Create Key
          </button>
        </div>

        {keys.map((k, i) => (
          <div key={i} style={{ marginBottom: 12, padding: 12, background: "#0f172a", borderRadius: 8 }}>
            <pre>{JSON.stringify(k, null, 2)}</pre>
            <button
              onClick={() => revoke(k.id)}
              style={{
                marginTop: 8,
                padding: "6px 10px",
                borderRadius: 6,
                border: "1px solid #ef4444",
                background: "transparent",
                color: "#ef4444",
                cursor: "pointer"
              }}
            >
              Revoke Key
            </button>
          </div>
        ))}
      </div>
    </Protected>
  );
}
EOF

echo "[+] Rebuilding admin-frontend"
cd /home/deploy/predictoraai
docker compose build admin-frontend --no-cache
docker compose up -d

echo "[+] PHASE 2.2 COMPLETE — Full Control Plane Actions Enabled."
