#!/usr/bin/env python3
import os
import re

ROOT = "/home/deploy/predictoraai/backend/app/app/predictora"

print("[Deterministic Refactor] Starting…")

# Safe replace function
def safe_replace(path, replacements):
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        original = content

        for old, new in replacements.items():
            content = content.replace(old, new)

        if content != original:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[PATCHED] {path}")
    except Exception as e:
        print(f"[ERROR] {path}: {e}")

# Walk all .py files
for root, dirs, files in os.walk(ROOT):
    for file in files:
        if not file.endswith(".py"):
            continue

        path = os.path.join(root, file)

        replacements = {
            # 1. Randomness → deterministic RNG
            "random.choice": "deterministic.choice",
            "random.uniform": "deterministic.uniform",
            "random.shuffle": "deterministic.shuffle",
            "random.sample": "deterministic.sample",
            "random.randint": "deterministic.randint",

            # 2. UUID → deterministic UUID
            "uuid.uuid4()": "deterministic.uuid()",

            # 3. time.time → deterministic timestamp
            "time.time()": "deterministic.timestamp()",

            # 4. In-memory EventStore → authoritative
            "self.events = []": "self.events = None  # deterministic: DB-backed",

            # 5. IdempotencyStore → authoritative
            "self.processed = set()": "self.processed = None  # deterministic: DB-backed",

            # 6. Pipeline processed flag
            "event.processed = True": "# deterministic: idempotency handled externally",
        }

        safe_replace(path, replacements)

print("[Deterministic Refactor] Completed.")
