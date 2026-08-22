import requests

class PredictoraClient:
    def __init__(self, base_url="http://localhost:8000", api_key="PREDICTORA_KEY_123"):
        self.base_url = base_url
        self.headers = {"X-API-Key": api_key}

    def _get(self, path):
        r = requests.get(self.base_url + path, headers=self.headers)
        r.raise_for_status()
        return r.json()

    def decision_graph(self):
        return self._get("/api/graph")

    def replay_timeline(self):
        return self._get("/api/replay")

    def memory_export(self):
        return self._get("/api/memory/export")

    def root_cause(self, event="billing"):
        return self._get(f"/api/rootcause/analyze?event={event}")
