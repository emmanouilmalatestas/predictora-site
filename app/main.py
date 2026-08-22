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
# ROUTERS
# -----------------------------
from app.routes.policy_tuning import router as tuning_router
from app.routes.policy_diff import router as diff_router
from app.routes.policy_history import router as history_router
from app.src.decision_engine.routes import router as decision_engine_router
from app.predictora.routes.certification import router as certification_router
from app.predictora.routes.certification_dashboard import router as certification_dashboard_router

# -----------------------------
# CORE RUNTIME (LAZY INIT)
# -----------------------------
from app.predictora.core.db import get_connection
from app.predictora.core.event_store import EventStore
from app.predictora.core.event_pipeline import EventPipeline
from app.predictora.core.execution_context import ExecutionContext

APP_TITLE = "Predictora Backend"
APP_VERSION = "2.0.0"

SECRET_KEY = os.getenv("PREDICTORA_SECRET_KEY", "CHANGE_THIS_SECRET")
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
            "/api/certification/run",
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
# LAZY RUNTIME INIT
# -----------------------------
DB_CONN = None

@app.on_event("startup")
async def startup_event():
    global DB_CONN
    try:
        DB_CONN = get_connection()
        app.event_store = EventStore(DB_CONN)

        app.event_pipeline = EventPipeline()
        app.event_pipeline.event_store = app.event_store

        app.runtime_context = ExecutionContext(
            tenant_id="default",
            plan_tier="pro",
            capability="runtime",
        )

        print("PredictoraOS runtime initialized.")
    except Exception as e:
        print(f"Runtime initialization failed: {e}")
        DB_CONN = None


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
