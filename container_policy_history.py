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
