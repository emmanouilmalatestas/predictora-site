#!/usr/bin/env bash
set -euo pipefail

ADMIN="/home/deploy/predictoraai/admin-frontend/app"

echo "[+] Installing Chart.js"
cd /home/deploy/predictoraai/admin-frontend
npm install chart.js react-chartjs-2

echo "[+] Creating /billing directory"
mkdir -p "$ADMIN/billing"

###############################################
# PLANS PAGE
###############################################
echo "[+] Adding Plans UI"
cat > "$ADMIN/billing/plans.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";
import Protected from "../protected";

export default function Plans() {
  const [plans, setPlans] = useState<any[]>([]);
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;

  useEffect(() => {
    axios.get("https://api.predictoraai.com/billing/plans")
      .then(res => setPlans(res.data.plans || []));
  }, []);

  return (
    <Protected>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Billing Plans</h1>
        {plans.map((p, i) => (
          <div key={i} style={{ marginBottom: 16, padding: 16, background: "#0f172a", borderRadius: 8 }}>
            <h2>{p.name}</h2>
            <p>Code: {p.code}</p>
            <p>Price: ${p.monthly_price}/month</p>
            <p>Limit: {p.request_limit_per_month} requests/month</p>
          </div>
        ))}
      </div>
    </Protected>
  );
}
EOF

###############################################
# SUBSCRIPTIONS PAGE
###############################################
echo "[+] Adding Subscriptions UI"
cat > "$ADMIN/billing/subscriptions.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";
import Protected from "../protected";

export default function Subscriptions() {
  const [subs, setSubs] = useState<any[]>([]);
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;

  useEffect(() => {
    axios.get("https://api.predictoraai.com/admin/subscriptions", {
      headers: { Authorization: `Bearer ${token}` }
    }).then(res => setSubs(res.data.subscriptions || []));
  }, [token]);

  return (
    <Protected>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Subscriptions</h1>
        {subs.map((s, i) => (
          <div key={i} style={{ marginBottom: 16, padding: 16, background: "#0f172a", borderRadius: 8 }}>
            <p><strong>{s.user_email}</strong></p>
            <p>Plan: {s.plan_code}</p>
            <p>Status: {s.active ? "Active" : "Inactive"}</p>
            <p>Period: {s.current_period_start} → {s.current_period_end}</p>
            <p>Stripe Sub ID: {s.stripe_subscription_id}</p>
          </div>
        ))}
      </div>
    </Protected>
  );
}
EOF

###############################################
# USAGE PAGE (WITH GRAPH)
###############################################
echo "[+] Adding Usage UI with Chart.js"
cat > "$ADMIN/billing/usage.tsx" << 'EOF'
"use client";
import React, { useEffect, useState } from "react";
import axios from "axios";
import Nav from "../nav";
import Protected from "../protected";
import { Line } from "react-chartjs-2";
import { Chart as ChartJS, LineElement, CategoryScale, LinearScale, PointElement } from "chart.js";

ChartJS.register(LineElement, CategoryScale, LinearScale, PointElement);

export default function Usage() {
  const [usage, setUsage] = useState<any[]>([]);
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;

  useEffect(() => {
    axios.get("https://api.predictoraai.com/admin/usage/monthly", {
      headers: { Authorization: `Bearer ${token}` }
    }).then(res => setUsage(res.data.usage || []));
  }, [token]);

  const labels = usage.map(u => `${u.user_email} (${u.month})`);
  const data = usage.map(u => u.request_count);

  return (
    <Protected>
      <Nav />
      <div style={{ padding: 24 }}>
        <h1>Monthly Usage</h1>

        <div style={{ width: "600px", marginTop: 24 }}>
          <Line
            data={{
              labels,
              datasets: [
                {
                  label: "Requests",
                  data,
                  borderColor: "#22c55e",
                  backgroundColor: "rgba(34,197,94,0.3)"
                }
              ]
            }}
          />
        </div>

        <div style={{ marginTop: 32 }}>
          {usage.map((u, i) => (
            <div key={i} style={{ marginBottom: 16, padding: 16, background: "#0f172a", borderRadius: 8 }}>
              <p><strong>{u.user_email}</strong></p>
              <p>Month: {u.month}</p>
              <p>Requests: {u.request_count}</p>
            </div>
          ))}
        </div>
      </div>
    </Protected>
  );
}
EOF

###############################################
# NAVIGATION UPDATE
###############################################
echo "[+] Updating navigation to include billing"
cat > "$ADMIN/nav.tsx" << 'EOF'
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
      <Link href="/billing/plans">Plans</Link>
      <Link href="/billing/subscriptions">Subscriptions</Link>
      <Link href="/billing/usage">Usage</Link>
      <Link href="/logout">Logout</Link>
    </div>
  );
}
EOF

###############################################
# REBUILD
###############################################
echo "[+] Rebuilding admin-frontend"
cd /home/deploy/predictoraai
docker compose build admin-frontend --no-cache
docker compose up -d

echo "[+] Phase 3.3 Admin Billing UI complete."
echo "    - Plans UI"
echo "    - Subscriptions UI"
echo "    - Usage graphs & tables"
echo "    - Navigation updated"
