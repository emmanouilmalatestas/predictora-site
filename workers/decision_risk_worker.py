#!/usr/bin/env python3
import subprocess
import json
import datetime

print("=== Decision Risk Worker ===")
print("Generated:", datetime.datetime.utcnow().isoformat(), "Z")

risk = {
    "nodes": 0,
    "pods": 0,
    "restarts": 0,
    "backend": 0,
    "traefik": 0,
    "prometheus": 0,
    "total_risk": 0
}

# Nodes
nodes = subprocess.check_output(["kubectl", "get", "nodes", "--no-headers"]).decode().strip().split("\n")
risk["nodes"] = 0 if len(nodes) >= 1 else 5

# Pods
pods = subprocess.check_output(["kubectl", "get", "pods", "-A", "--no-headers"]).decode().strip().split("\n")
risk["pods"] = 0 if len(pods) >= 5 else 3

# Restarts
restarts_raw = subprocess.check_output(["kubectl", "get", "pods", "-A", "--no-headers"]).decode().strip().split("\n")
restart_count = 0
for line in restarts_raw:
    parts = line.split()
    if len(parts) >= 4 and parts[3].isdigit():
        restart_count += int(parts[3])
risk["restarts"] = 0 if restart_count < 5 else 4

# Backend
try:
    backend = subprocess.check_output(["curl", "-s", "--max-time", "2", "http://predictora-backend:8000/health"]).decode().strip()
    risk["backend"] = 0 if backend else 5
except:
    risk["backend"] = 5

# Traefik
try:
    traefik_raw = subprocess.check_output(["curl", "-s", "--max-time", "2", "http://10.43.40.156:8080/api/rawdata"]).decode().strip()
    traefik_json = json.loads(traefik_raw)
    routers = len(traefik_json.get("routers", []))
    risk["traefik"] = 0 if routers >= 1 else 2
except:
    risk["traefik"] = 2

# Prometheus
try:
    prom = subprocess.check_output(["curl", "-s", "--max-time", "2", "http://10.43.64.176:9090/-/ready"]).decode().strip()
    risk["prometheus"] = 0 if "Ready" in prom else 3
except:
    risk["prometheus"] = 3

# Total risk
risk["total_risk"] = sum(risk.values())

print(json.dumps(risk, indent=2))
print("=== Decision Risk Worker Completed ===")
