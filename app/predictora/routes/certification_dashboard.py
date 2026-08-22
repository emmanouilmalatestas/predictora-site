# app/app/predictora/routes/certification_dashboard.py
import json
import os
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/certification", tags=["certification"])

CERT_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "predictora_certification.json")
)

@router.get("/dashboard")
def get_certification_dashboard():
    if not os.path.exists(CERT_PATH):
        raise HTTPException(status_code=404, detail="Certification report not found")

    try:
        with open(CERT_PATH) as f:
            data = json.load(f)
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to read certification report")

    report = data.get("PredictoraOS Enterprise Certification")
    if not report:
        raise HTTPException(status_code=500, detail="Invalid certification report format")

    return {
        "version": report.get("version"),
        "mode": report.get("mode", "A"),
        "overall_score": report.get("overall_score"),
        "level": report.get("level"),
        "started_at": report.get("started_at"),
        "suites": report.get("suites", {}),
    }
