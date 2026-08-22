from fastapi import APIRouter, HTTPException
from pathlib import Path
import json

from app.predictora.operations.certification_api import run_all_suites

router = APIRouter()

CERT_CACHE_PATH = Path(__file__).parent.parent / "predictora_certification.json"


def load_cached_cert():
    if not CERT_CACHE_PATH.exists():
        raise HTTPException(
            status_code=500,
            detail="Certification cache not found.",
        )
    data = json.loads(CERT_CACHE_PATH.read_text(encoding="utf-8"))
    return data["PredictoraOS Enterprise Certification"]


def write_cert_cache(cert: dict):
    payload = {
        "PredictoraOS Enterprise Certification": cert
    }
    CERT_CACHE_PATH.write_text(json.dumps(payload, indent=2), encoding="utf-8")


@router.post("/api/certification/run")
def certification_run():
    result = run_all_suites()
    write_cert_cache(result["PredictoraOS Enterprise Certification"])
    return result


@router.get("/api/certification")
def certification_get():
    return load_cached_cert()
