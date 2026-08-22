#!/usr/bin/env python3
import subprocess
import json
import datetime

print("=== Automation Playbook Runner ===")
print("Generated:", datetime.datetime.utcnow().isoformat(), "Z")

playbook = {
    "actions": [],
    "executed": [],
    "status": "OK"
}

# 1. Backend auto-check
try:
    backend = subprocess.check_output(["curl", "-s", "--max-time", "2", "http://predictora-backend:8000/health"]).decode().strip()
    if not backend:
        playbook["actions"].append("backend_missing")
except:
    playbook["actions"].append("backend_missing")

# 2. Traefik auto-check
try:
    traefik_raw = subprocess.check_output(["curl", "-s", "--max-time", "2", "http://10.43.40.156:8080/api/rawdata"]).decode().strip()
    traefik_json = json.loads(traefik_raw)
    routers = len(traefik_json.get("routers", []))
    if routers == 0:
        playbook["actions"].append("traefik_no_routers")
except:
    playbook["actions"].append("traefik_no_routers")

# 3. Prometheus auto-check
try:
    prom = subprocess.check_output(["curl", "-s", "--max-time", "2", "http://10.43.64.176:9090/-/ready"]).decode().strip()
    if "Ready" not in prom:
        playbook["actions"].append("prometheus_not_ready")
except:
    playbook["actions"].append("prometheus_not_ready")

# Execute actions
for action in playbook["actions"]:
    if action == "backend_missing":
        playbook["executed"].append("notify_backend_missing")
    if action == "traefik_no_routers":
        playbook["executed"].append("notify_traefik_admin_api")
    if action == "prometheus_not_ready":
        playbook["executed"].append("notify_prometheus")

print(json.dumps(playbook, indent=2))
print("=== Automation Playbook Runner Completed ===")
