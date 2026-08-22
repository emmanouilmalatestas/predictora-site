#!/usr/bin/env python3
import datetime
import subprocess
from pathlib import Path

print("=== Replay Timeline ===")
print("Generated:", datetime.datetime.utcnow().isoformat(), "Z")

LOG_PATH = Path("/tmp/replay.log")

try:
    subprocess.run(
        ["journalctl", "-u", "predictora-backend", "--since", "5 min ago"],
        stdout=open(LOG_PATH, "w"),
        stderr=subprocess.STDOUT,
        check=True
    )
except Exception as e:
    print("Failed to collect logs:", e)
    exit(1)

if LOG_PATH.exists():
    for line in LOG_PATH.open():
        print(line.rstrip())
else:
    print("No replay.log found.")
