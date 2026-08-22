#!/bin/bash

echo "=============================================="
echo "  PREDICTORAAI — ADMIN CONTROL PLANE SETUP"
echo "=============================================="

BASE="backend/src/admin/control_plane"

echo "[1/6] Creating control_plane directory..."
mkdir -p $BASE

echo "[2/6] Creating lockdown_controller.py..."
cat > $BASE/lockdown_controller.py << 'EOF'
from fastapi import APIRouter, Depends, Request
from src.security.admin_middleware import require_admin, enable_lockdown, disable_lockdown, lockdown_status
from src.admin.admin_activity_feed import publish_admin_event

router = APIRouter(prefix="/admin/control/lockdown", tags=["admin-lockdown"])

@router.post("/enable")
def lockdown_enable(request: Request, user = Depends(require_admin)):
    publish_admin_event("lockdown_enabled", user["sub"], request.url.path)
    return enable_lockdown()

@router.post("/disable")
def lockdown_disable(request: Request, user = Depends(require_admin)):
    publish_admin_event("lockdown_disabled", user["sub"], request.url.path)
    return disable_lockdown()

@router.get("/status")
def lockdown_get_status(request: Request, user = Depends(require_admin)):
    publish_admin_event("lockdown_status", user["sub"], request.url.path)
    return lockdown_status()
EOF

echo "[3/6] Creating sessions_controller.py..."
cat > $BASE/sessions_controller.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Request
from src.security.admin_middleware import require_admin
from src.admin.admin_sessions import ADMIN_SESSIONS, session_exists, delete_session
from src.admin.admin_activity_feed import publish_admin_event

router = APIRouter(prefix="/admin/sessions", tags=["admin-sessions"])

@router.get("/active")
def list_active_sessions(request: Request, user = Depends(require_admin)):
    publish_admin_event("list_sessions", user["sub"], request.url.path)
    return list(ADMIN_SESSIONS.values())

@router.delete("/force/{session_id}")
def force_logout(session_id: str, request: Request, user = Depends(require_admin)):
    if not session_exists(session_id):
        raise HTTPException(status_code=404, detail="Session not found")

    delete_session(session_id)
    publish_admin_event("force_logout", user["sub"], request.url.path)

    return {"detail": "Session terminated", "session_id": session_id}

@router.delete("/purge")
def purge_all_sessions(request: Request, user = Depends(require_admin)):
    ADMIN_SESSIONS.clear()
    publish_admin_event("purge_sessions", user["sub"], request.url.path)
    return {"detail": "All sessions purged"}

@router.get("/stats")
def session_stats(request: Request, user = Depends(require_admin)):
    publish_admin_event("session_stats", user["sub"], request.url.path)
    return {
        "active_sessions": len(ADMIN_SESSIONS),
        "sessions": list(ADMIN_SESSIONS.values())
    }
EOF

echo "[4/6] Creating activity_controller.py..."
cat > $BASE/activity_controller.py << 'EOF'
from fastapi import APIRouter, Depends, Request
from src.security.admin_middleware import require_admin
from src.admin.admin_activity_feed import ACTIVITY_FEED, publish_admin_event

router = APIRouter(prefix="/admin/activity", tags=["admin-activity"])

@router.get("/recent")
def recent_activity(request: Request, user = Depends(require_admin)):
    publish_admin_event("activity_view", user["sub"], request.url.path)
    return ACTIVITY_FEED[-50:]

@router.get("/all")
def all_activity(request: Request, user = Depends(require_admin)):
    publish_admin_event("activity_view_all", user["sub"], request.url.path)
    return ACTIVITY_FEED
EOF

echo "[5/6] Creating admin_control_plane.py..."
cat > $BASE/admin_control_plane.py << 'EOF'
from fastapi import APIRouter

from .lockdown_controller import router as lockdown_router
from .sessions_controller import router as sessions_router
from .activity_controller import router as activity_router

router = APIRouter()

router.include_router(lockdown_router)
router.include_router(sessions_router)
router.include_router(activity_router)
EOF

echo "[6/6] Adding import to main.py (manual step)"
echo "Add this line to backend/main.py:"
echo "    from src.admin.control_plane.admin_control_plane import router as admin_control_plane_router"
echo "    app.include_router(admin_control_plane_router)"

echo "=============================================="
echo "  ADMIN CONTROL PLANE INSTALLED SUCCESSFULLY"
echo "=============================================="
