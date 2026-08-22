#!/usr/bin/env bash
set -e

BASE_DIR="/home/deploy/predictoraai"
BACKEND_DIR="$BASE_DIR/backend/app"
PREDICTORA_DIR="$BACKEND_DIR/predictora"
MIGRATIONS_DIR="$BACKEND_DIR/migrations"

echo "[1] Create audit migration..."
cat > "$MIGRATIONS_DIR/20260805_policy_audit.sql" << 'EOF'
CREATE TABLE IF NOT EXISTS policy_runs_audit (
    id UUID PRIMARY KEY,
    run_id TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    input_payload JSONB NOT NULL,
    output_payload JSONB NOT NULL,
    risk_score FLOAT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
EOF

echo "[2] Apply audit migration..."
docker exec -i predictoraai-db psql -U predictora -d predictora < "$MIGRATIONS_DIR/20260805_policy_audit.sql"

echo "[3] Create policy_audit module..."
cat > "$PREDICTORA_DIR/policy_audit.py" << 'EOF'
import uuid
from datetime import datetime
from psycopg2.extras import Json
from backend.app.db import get_db

def log_policy_run(run_id, policy_version, input_payload, output_payload, risk_score):
    conn = get_db()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO policy_runs_audit (id, run_id, policy_version, input_payload, output_payload, risk_score, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (
            str(uuid.uuid4()),
            run_id,
            policy_version,
            Json(input_payload),
            Json(output_payload),
            risk_score,
            datetime.utcnow()
        )
    )
    conn.commit()
EOF

echo "[4] Create policy_diff module..."
cat > "$PREDICTORA_DIR/policy_diff.py" << 'EOF'
import json

def diff_policies(base_policy_path, compare_policy_path):
    with open(base_policy_path) as f1, open(compare_policy_path) as f2:
        base = json.load(f1)
        comp = json.load(f2)

    diffs = []
    for key in base:
        if key not in comp:
            diffs.append({"field": key, "old": base[key], "new": None})
        elif base[key] != comp[key]:
            diffs.append({"field": key, "old": base[key], "new": comp[key]})
    for key in comp:
        if key not in base:
            diffs.append({"field": key, "old": None, "new": comp[key]})
    return diffs
EOF

echo "[5] Create policy_history route..."
cat > "$BACKEND_DIR/routes/policy_history.py" << 'EOF'
from fastapi import APIRouter
from backend.app.db import get_db

router = APIRouter()

@router.get("/policies/runs")
def policy_runs(policy_version: str, limit: int = 100):
    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        SELECT run_id, policy_version, risk_score, created_at
        FROM policy_runs_audit
        WHERE policy_version = %s
        ORDER BY created_at DESC
        LIMIT %s
    """, (policy_version, limit))
    rows = cur.fetchall()
    return [
        {
            "run_id": r[0],
            "policy_version": r[1],
            "risk_score": r[2],
            "created_at": r[3]
        }
        for r in rows
    ]
EOF

echo "[6] Create policy_diff route..."
cat > "$BACKEND_DIR/routes/policy_diff.py" << 'EOF'
from fastapi import APIRouter
from predictora.policy_diff import diff_policies

router = APIRouter()

@router.get("/policies/diff")
def policy_diff(base: str, compare: str):
    base_path = f"/home/deploy/predictoraai/policy_{base}.json"
    compare_path = f"/home/deploy/predictoraai/policy_{compare}.json"
    return diff_policies(base_path, compare_path)
EOF

echo "[7] Create auto_tuning module..."
cat > "$PREDICTORA_DIR/auto_tuning.py" << 'EOF'
def suggest_thresholds(history):
    if not history:
        return []

    avg_risk = sum([h["risk_score"] for h in history]) / len(history)
    suggestions = []

    if avg_risk > 0.7:
        suggestions.append({
            "field": "max_transaction",
            "current": "dynamic",
            "suggested": "lower",
            "reason": "High average risk score"
        })

    return suggestions
EOF

echo "[8] Create policy_tuning route..."
cat > "$BACKEND_DIR/routes/policy_tuning.py" << 'EOF'
from fastapi import APIRouter
from routes.policy_history import policy_runs
from predictora.auto_tuning import suggest_thresholds

router = APIRouter()

@router.get("/policies/tuning")
def tuning(policy_version: str):
    history = policy_runs(policy_version, limit=200)
    return suggest_thresholds(history)
EOF

echo "[9] Wire routes into main FastAPI app..."
MAIN_FILE="$BACKEND_DIR/main.py"

if ! grep -q "from routes.policy_history" "$MAIN_FILE"; then
  sed -i '1i from routes.policy_history import router as history_router' "$MAIN_FILE"
  sed -i '1i from routes.policy_diff import router as diff_router' "$MAIN_FILE"
  sed -i '1i from routes.policy_tuning import router as tuning_router' "$MAIN_FILE"
  sed -i 's/app = FastAPI()/app = FastAPI()\napp.include_router(history_router)\napp.include_router(diff_router)\napp.include_router(tuning_router)/' "$MAIN_FILE"
fi

echo "[10] Rebuild backend + UI..."
cd "$BASE_DIR"
docker compose -f docker-compose.prod.yml up -d --build

echo "[DONE] Policy diff, risk timeline API, auto_tuning, audit store are wired."
echo "Test:"
echo "  curl https://api.predictoraai.com/policies/diff?base=v2&compare=v2_enterprise"
echo "  curl https://api.predictoraai.com/policies/runs?policy_version=v2_enterprise"
echo "  curl https://api.predictoraai.com/policies/tuning?policy_version=v2_enterprise"
