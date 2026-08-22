// ============================================================
//   WARZONE DEVELOPER PORTAL – PredictoraAI
//   API Keys • Usage • Credits • Billing • Marketplace
// ============================================================

import React, { useEffect, useState } from "react";

export default function DeveloperPortal() {
  const [apiKey, setApiKey] = useState("");
  const [usage, setUsage] = useState([]);
  const [credits, setCredits] = useState(0);
  const [billingEvents, setBillingEvents] = useState([]);
  const [loading, setLoading] = useState(false);

  // ------------------------------------------------------------
  // 1) Fetch usage + credits + billing from backend
  // ------------------------------------------------------------
  async function fetchData() {
    if (!apiKey) return;
    setLoading(true);

    const headers = { "x-api-key": apiKey };

    const usageRes = await fetch("https://api.predictoraai.com/metrics", {
      headers,
    }).then((r) => r.text());

    // Parse Prometheus metrics
    const parsedUsage = usageRes
      .split("\n")
      .filter((l) => l.includes("api_usage_total"))
      .map((line) => {
        const match = line.match(/api_usage_total\{api_key="(.+)",path="(.+)"\} (\d+)/);
        if (!match) return null;
        return {
          key: match[1],
          path: match[2],
          count: Number(match[3]),
        };
      })
      .filter(Boolean);

    const parsedCredits = usageRes
      .split("\n")
      .find((l) => l.includes(`api_credit_balance{api_key="${apiKey}"}`));

    const creditValue = parsedCredits
      ? Number(parsedCredits.split(" ").pop())
      : 0;

    const parsedBilling = usageRes
      .split("\n")
      .filter((l) => l.includes("billing_events_total"))
      .map((line) => {
        const match = line.match(
          /billing_events_total\{api_key="(.+)",event="(.+)"\} (\d+)/
        );
        if (!match) return null;
        return {
          key: match[1],
          event: match[2],
          count: Number(match[3]),
        };
      })
      .filter(Boolean);

    setUsage(parsedUsage);
    setCredits(creditValue);
    setBillingEvents(parsedBilling);
    setLoading(false);
  }

  // ------------------------------------------------------------
  // 2) UI
  // ------------------------------------------------------------
  return (
    <div className="min-h-screen bg-gray-950 text-white p-10 font-sans">
      <div className="max-w-4xl mx-auto space-y-10">

        {/* Header */}
        <h1 className="text-4xl font-bold text-center">
          PredictoraAI Developer Portal
        </h1>
        <p className="text-center text-gray-400">
          API Keys • Usage • Credits • Billing • Marketplace
        </p>

        {/* API Key Input */}
        <div className="bg-gray-900 p-6 rounded-xl shadow-xl">
          <label className="block mb-2 text-gray-400">Enter API Key</label>
          <input
            type="text"
            className="w-full p-3 rounded bg-gray-800 border border-gray-700"
            placeholder="x-api-key"
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
          />
          <button
            onClick={fetchData}
            className="mt-4 w-full bg-blue-600 hover:bg-blue-700 p-3 rounded font-bold"
          >
            {loading ? "Loading..." : "Load Usage"}
          </button>
        </div>

        {/* Credits */}
        <div className="bg-gray-900 p-6 rounded-xl shadow-xl">
          <h2 className="text-2xl font-bold mb-4">Credits</h2>
          <p className="text-4xl font-bold text-green-400">{credits}</p>
          <p className="text-gray-400 mt-2">Remaining credits</p>
        </div>

        {/* Usage Table */}
        <div className="bg-gray-900 p-6 rounded-xl shadow-xl">
          <h2 className="text-2xl font-bold mb-4">API Usage</h2>
          <table className="w-full text-left">
            <thead>
              <tr className="text-gray-400">
                <th className="p-2">Endpoint</th>
                <th className="p-2">Calls</th>
              </tr>
            </thead>
            <tbody>
              {usage.map((u, i) => (
                <tr key={i} className="border-t border-gray-800">
                  <td className="p-2">{u.path}</td>
                  <td className="p-2">{u.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Billing Events */}
        <div className="bg-gray-900 p-6 rounded-xl shadow-xl">
          <h2 className="text-2xl font-bold mb-4">Billing Events</h2>
          <table className="w-full text-left">
            <thead>
              <tr className="text-gray-400">
                <th className="p-2">Event</th>
                <th className="p-2">Count</th>
              </tr>
            </thead>
            <tbody>
              {billingEvents.map((b, i) => (
                <tr key={i} className="border-t border-gray-800">
                  <td className="p-2">{b.event}</td>
                  <td className="p-2">{b.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Marketplace CTA */}
        <div className="bg-gray-900 p-6 rounded-xl shadow-xl text-center">
          <h2 className="text-2xl font-bold mb-4">PredictoraAI Marketplace</h2>
          <p className="text-gray-400 mb-4">
            Buy credits, upgrade plans, and access premium APIs.
          </p>
          <button className="bg-purple-600 hover:bg-purple-700 p-3 rounded font-bold w-full">
            Open Marketplace
          </button>
        </div>
      </div>
    </div>
  );
}
