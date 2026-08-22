// ============================================================
//   WARZONE MARKETPLACE FRONTEND – PredictoraAI
//   Plans • Credit Packs • Stripe Checkout • Billing UI
// ============================================================

import React, { useEffect, useState } from "react";

export default function Marketplace() {
  const [apiKey, setApiKey] = useState("");
  const [items, setItems] = useState({ plans: {}, credit_packs: {} });
  const [billing, setBilling] = useState([]);
  const [loading, setLoading] = useState(false);

  // ------------------------------------------------------------
  // 1) Load marketplace items
  // ------------------------------------------------------------
  async function loadItems() {
    const res = await fetch("https://api.predictoraai.com/marketplace/items");
    const data = await res.json();
    setItems(data);
  }

  // ------------------------------------------------------------
  // 2) Load billing history
  // ------------------------------------------------------------
  async function loadBilling() {
    if (!apiKey) return;
    const res = await fetch(
      `https://api.predictoraai.com/marketplace/billing/${apiKey}`
    );
    const data = await res.json();
    setBilling(data);
  }

  // ------------------------------------------------------------
  // 3) Stripe Checkout
  // ------------------------------------------------------------
  async function checkout(itemId) {
    if (!apiKey) {
      alert("Enter your API key first");
      return;
    }

    setLoading(true);

    const res = await fetch(
      "https://api.predictoraai.com/marketplace/checkout",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ api_key: apiKey, item_id: itemId }),
      }
    );

    const data = await res.json();
    setLoading(false);

    if (data.checkout_url) {
      window.location.href = data.checkout_url;
    } else {
      alert("Checkout failed");
    }
  }

  // ------------------------------------------------------------
  // 4) Load items on mount
  // ------------------------------------------------------------
  useEffect(() => {
    loadItems();
  }, []);

  // ------------------------------------------------------------
  // 5) UI
  // ------------------------------------------------------------
  return (
    <div className="min-h-screen bg-gray-950 text-white p-10 font-sans">
      <div className="max-w-5xl mx-auto space-y-12">

        {/* Header */}
        <h1 className="text-4xl font-bold text-center">
          PredictoraAI Marketplace
        </h1>
        <p className="text-center text-gray-400">
          Buy credits • Upgrade plans • View billing history
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
            onClick={loadBilling}
            className="mt-4 w-full bg-blue-600 hover:bg-blue-700 p-3 rounded font-bold"
          >
            Load Billing History
          </button>
        </div>

        {/* Plans */}
        <div className="bg-gray-900 p-6 rounded-xl shadow-xl">
          <h2 className="text-3xl font-bold mb-6">Subscription Plans</h2>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {Object.entries(items.plans).map(([id, plan]) => (
              <div
                key={id}
                className="bg-gray-800 p-6 rounded-xl border border-gray-700"
              >
                <h3 className="text-xl font-bold">{plan.name}</h3>
                <p className="text-gray-400 mt-2">
                  {plan.monthly_credits.toLocaleString()} credits / month
                </p>
                <p className="text-3xl font-bold mt-4">
                  {plan.price === 0 ? "Free" : `$${plan.price}`}
                </p>

                {plan.price > 0 && (
                  <button
                    onClick={() => checkout(id)}
                    className="mt-4 w-full bg-purple-600 hover:bg-purple-700 p-3 rounded font-bold"
                  >
                    {loading ? "Loading..." : "Upgrade"}
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Credit Packs */}
        <div className="bg-gray-900 p-6 rounded-xl shadow-xl">
          <h2 className="text-3xl font-bold mb-6">Credit Packs</h2>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {Object.entries(items.credit_packs).map(([id, pack]) => (
              <div
                key={id}
                className="bg-gray-800 p-6 rounded-xl border border-gray-700"
              >
                <h3 className="text-xl font-bold">
                  {pack.credits.toLocaleString()} Credits
                </h3>
                <p className="text-3xl font-bold mt-4">${pack.price}</p>

                <button
                  onClick={() => checkout(id)}
                  className="mt-4 w-full bg-green-600 hover:bg-green-700 p-3 rounded font-bold"
                >
                  {loading ? "Loading..." : "Buy Credits"}
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Billing History */}
        <div className="bg-gray-900 p-6 rounded-xl shadow-xl">
          <h2 className="text-3xl font-bold mb-6">Billing History</h2>

          {billing.length === 0 ? (
            <p className="text-gray-400">No billing events found</p>
          ) : (
            <table className="w-full text-left">
              <thead>
                <tr className="text-gray-400">
                  <th className="p-2">Event</th>
                  <th className="p-2">Amount</th>
                  <th className="p-2">Credits</th>
                  <th className="p-2">Timestamp</th>
                </tr>
              </thead>
              <tbody>
                {billing.map((b, i) => (
                  <tr key={i} className="border-t border-gray-800">
                    <td className="p-2">{b.event}</td>
                    <td className="p-2">${b.amount}</td>
                    <td className="p-2">{b.metadata?.credits}</td>
                    <td className="p-2">{b.timestamp}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

      </div>
    </div>
  );
}
