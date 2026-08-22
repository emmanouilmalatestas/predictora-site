const API_BASE = "http://localhost:8000";
const HEADERS = { "X-API-Key": "PREDICTORA_KEY_123" };

async function get(path: string) {
  const res = await fetch(`${API_BASE}${path}`, { headers: HEADERS });
  if (!res.ok) throw new Error(`PredictoraOS API error: ${res.status}`);
  return res.json();
}

export const Predictora = {
  decisionGraph: () => get("/api/graph"),
  replayTimeline: () => get("/api/replay"),
  memoryExport: () => get("/api/memory/export"),
  rootCause: (event = "billing") =>
    get(`/api/rootcause/analyze?event=${event}`),
};
