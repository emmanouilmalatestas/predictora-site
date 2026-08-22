#!/usr/bin/env python3
import datetime
import subprocess
import json

print("=== Executive Morning Briefing ===")
print("Generated:", datetime.datetime.utcnow().isoformat(), "Z")

brief = {
    "uptime": "N/A",
    "incidents_24h": 0,
    "impact": "N/A",
    "risk_score": 0,
    "top_risk": "N/A",
    "next_actions": []
}

# 1. Uptime (Prometheus)
try:
    prom_ready = subprocess.check_output(
        ["curl", "-s", "--max-time", "2", "http://10.43.64.176:9090/-/ready"]
    ).decode().strip()
    brief["uptime"] = "100%" if "Ready" in prom_ready else "Degraded"
except:
    brief["uptime"] = "Unknown"

# 2. Incidents (journalctl)
try:
    logs = subprocess.check_output(
        ["journalctl", "--since", "24 hours ago", "-u", "predictora-backend", "--no-pager"]
    ).decode().strip().split("\n")
    brief["incidents_24h"] = len([l for l in logs if "ERROR" in l or "Fail" in l])
except:
    brief["incidents_24h"] = 0

# 3. Risk score (Decision Risk Worker)
try:
    risk_raw = subprocess.check_output(
        ["/home/deploy/predictoraai/workers/decision_risk_worker.py"]
    ).decode().strip()
    risk_json = json.loads(risk_raw.split("Completed")[0].split("{",1)[1].rsplit("}",1)[0])
    brief["risk_score"] = risk_json.get("total_risk", 0)
except:
    brief["risk_score"] = 0

# 4. Top risk
if brief["risk_score"] >= 10:
    brief["top_risk"] = "Critical cluster instability"
elif brief["risk_score"] >= 7:
    brief["top_risk"] = "Backend missing + Traefik admin API"
elif brief["risk_score"] >= 3:
    brief["top_risk"] = "Minor instability"
else:
    brief["top_risk"] = "Stable"

# 5. Next actions
if brief["risk_score"] >= 7:
    brief["next_actions"].append("Restore backend service")
    brief["next_actions"].append("Verify Traefik admin API availability")
elif brief["risk_score"] >= 3:
    brief["next_actions"].append("Monitor cluster health")
else:
    brief["next_actions"].append("No action required")

print(json.dumps(brief, indent=2))
print("=== Executive Morning Briefing Completed ===")

