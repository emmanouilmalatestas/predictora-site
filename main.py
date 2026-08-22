from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware import Middleware
from jose import jwt, JWTError
from starlette.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel
from pathlib import Path
import json
import os

# -----------------------------
# ROUTERS (CORRECT IMPORT PATHS)
# -----------------------------
from app.routes.policy_tuning import router as tuning_router
from app.routes.policy_diff import router as diff_router
from app.routes.policy_history import router as history_router

from app.predictora.routes.certification import router as certification_router
from app.predictora.operations import certification_api
from app.src.decision_engine.routes import router as decision_engine_router

from app.predictora.core.db import get_connection
from app.predictora.core.event_store_authoritative import AuthoritativeEventStore
from app.predictora.core.idempotency_store import IdempotencyStore
from app.predictora.core.event_pipeline import EventPipeline
from app.predictora.core.execution_context import ExecutionContext
from app.predictora.routes.certification_dashboard import router as certification_dashboard_router

from container_routes.trace import router as trace_router
from container_routes.runtime_replay import router as replay_router
from container_routes.runtime_trace import router as runtime_trace_router

APP_TITLE = "Predictora Backend"
APP_VERSION = "1.0.0"

SECRET_KEY = os.getenv("PREDICTORA_SECRET_KEY", "CHANGE_THIS_TO_YOUR_REAL_SECRET_KEY")
ALGORITHM = "HS256"

API_KEY_HEADER_NAME = "X-API-Key"
EXPECTED_API_KEY = os.getenv("PREDICTORA_API_KEY", "PREDICTORA_KEY_123")

ADMIN_EMAIL = os.getenv("PREDICTORA_ADMIN_EMAIL", "admin@predictora.ai")
ADMIN_PASSWORD = os.getenv("PREDICTORA_ADMIN_PASSWORD", "PredictoraAdmin123!")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


class APIKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        open_paths = {
            "/",
            "/metrics",
            "/health",
            "/api/health",
            "/openapi.json",
            "/docs",
            "/redoc",
            "/auth/login",
            "/stripe/webhook",
            "/api/certification",
            "/api/runtime",
            "/api/chaos",
            "/api/certification/dashboard",
        }

        if any(request.url.path.startswith(p) for p in open_paths):
            return await call_next(request)

        api_key = request.headers.get(API_KEY_HEADER_NAME)
        if not api_key or api_key != EXPECTED_API_KEY:
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content={"detail": "Invalid or missing API key"},
            )

        return await call_next(request)


middleware = [
    Middleware(APIKeyMiddleware)
]

# -----------------------------
# FASTAPI APP
# -----------------------------
app = FastAPI(
    title=APP_TITLE,
    version=APP_VERSION,
    middleware=middleware,
)

Instrumentator().instrument(app).expose(app)

# -----------------------------
# DATABASE + EVENT RUNTIME
# -----------------------------
DB_CONN = get_connection()

# Authoritative deterministic stores
app.event_store = AuthoritativeEventStore(DB_CONN)
app.idempotency_store = IdempotencyStore(DB_CONN)

# Deterministic pipeline
app.event_pipeline = EventPipeline(app.idempotency_store)

app.runtime_context = ExecutionContext(
    tenant_id="default",
    plan_tier="pro",
    capability="runtime",
)

# -----------------------------
# ROUTERS
# -----------------------------
app.include_router(trace_router)
app.include_router(replay_router)
app.include_router(runtime_trace_router)
app.include_router(decision_engine_router)
app.include_router(certification_router)
app.include_router(tuning_router)
app.include_router(diff_router)
app.include_router(history_router)
app.include_router(certification_dashboard_router)

CERT_PATH = Path("/app/predictora_certification.json")

def load_cert():
    if not CERT_PATH.exists():
        raise HTTPException(
            status_code=500,
            detail="Certification JSON not found.",
        )
    data = json.loads(CERT_PATH.read_text(encoding="utf-8"))
    return data["PredictoraOS Enterprise Certification"]


@app.get("/api/health")
async def api_health():
    return {"status": "ok"}


@app.get("/api/certification")
async def api_certification():
    return load_cert()


@app.get("/api/runtime")
async def api_runtime():
    cert = load_cert()
    return {
        "version": cert["version"],
        "overall_score": cert["overall_score"],
        "level": cert["level"],
        "started_at": cert["started_at"],
        "runtime_integrity": cert["suites"]["runtime_integrity"],
    }


@app.get("/api/chaos")
async def api_chaos():
    cert = load_cert()
    return {
        "version": cert["version"],
        "overall_score": cert["overall_score"],
        "level": cert["level"],
        "started_at": cert["started_at"],
        "chaos_integrity": cert["suites"]["chaos_integrity"],
    }


@app.get("/")
async def root():
    return {"status": "ok", "service": "Predictora Backend"}


class LoginRequest(BaseModel):
    email: str
    password: str


def create_access_token(email: str, role: str = "admin"):
    from datetime import datetime, timedelta

    expire = datetime.utcnow() + timedelta(hours=1)
    payload = {
        "sub": email,
        "role": role,
        "exp": expire,
        "iat": datetime.utcnow(),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email = payload.get("sub")
        role = payload.get("role")

        if email is None or role is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload",
            )

        return {"email": email, "role": role, "exp": payload.get("exp")}

    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )


def require_role(required_role: str):
    def checker(user: dict):
        if user.get("role") != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return True

    return checker


@app.post("/auth/login")
async def login(body: LoginRequest):
    if body.email != ADMIN_EMAIL or body.password != ADMIN_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    token = create_access_token(email=body.email, role="admin")
    return {"access_token": token, "token_type": "bearer"}


@app.get("/auth/me")
async def auth_me(user: dict = Depends(get_current_user)):
    return {
        "email": user["email"],
        "role": user["role"],
        "session_expires": user["exp"],
    }


@app.get("/secure/data")
async def secure_data(user: dict = Depends(get_current_user)):
    require_role("admin")(user)
    return {
        "message": "Secure data access granted",
        "user": user["email"],
        "role": user["role"],
    }


@app.post("/stripe/webhook")
async def stripe_webhook():
    return {"status": "ok"}


@app.get("/health")
async def health():
    return {"status": "ok"}
