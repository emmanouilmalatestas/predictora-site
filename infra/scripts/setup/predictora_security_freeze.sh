#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/deploy/predictoraai"
BACKEND_ROOT="$PROJECT_ROOT/backend"
SRC_ROOT="$BACKEND_ROOT/src"

echo "=== PREDICTORAAI SECURITY FREEZE LINE (WARZONE) ==="

mkdir -p \
  "$SRC_ROOT/security" \
  "$SRC_ROOT/audit" \
  "$SRC_ROOT/models" \
  "$BACKEND_ROOT/scripts"

########################################
# 1. Argon2id password helpers
########################################
cat > "$SRC_ROOT/security/passwords.py" << 'EOF'
from argon2 import PasswordHasher
from argon2.low_level import Type

# Argon2id, tuned for server-side hashing
_ph = PasswordHasher(
    time_cost=3,
    memory_cost=64 * 1024,  # 64 MB
    parallelism=4,
    hash_len=32,
    type=Type.ID,
)

def hash_password(plain: str) -> str:
    return _ph.hash(plain)

def verify_password(plain: str, hashed: str) -> bool:
    try:
        return _ph.verify(hashed, plain)
    except Exception:
        return False
EOF

########################################
# 2. IP utils (X-Forwarded-For aware)
########################################
cat > "$SRC_ROOT/security/ip_utils.py" << 'EOF'
from fastapi import Request

def get_client_ip(request: Request) -> str:
    """
    X-Forwarded-For aware client IP extraction.
    Works correctly behind Traefik / reverse proxies.
    """
    xff = request.headers.get("x-forwarded-for")
    if xff:
        # Take first IP in chain
        return xff.split(",")[0].strip()
    return request.client.host
EOF

########################################
# 3. Lockout & login security service
########################################
cat > "$SRC_ROOT/security/login_security.py" << 'EOF'
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from src.models.user import User  # assumes existing User model with fields below

MAX_FAILED_ATTEMPTS = 5
LOCKOUT_MINUTES = 15

def is_account_locked(user: User) -> bool:
    if not user.locked_until:
        return False
    now = datetime.now(timezone.utc)
    return user.locked_until > now

def register_failed_login(db: Session, user: User) -> None:
    now = datetime.now(timezone.utc)
    user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
    if user.failed_login_attempts >= MAX_FAILED_ATTEMPTS:
        user.locked_until = now + timedelta(minutes=LOCKOUT_MINUTES)
    db.add(user)
    db.commit()

def register_successful_login(db: Session, user: User, ip: str) -> None:
    now = datetime.now(timezone.utc)
    user.failed_login_attempts = 0
    user.locked_until = None
    user.last_login_at = now
    user.last_login_ip = ip
    db.add(user)
    db.commit()
EOF

########################################
# 4. MFA (TOTP + recovery codes)
########################################
cat > "$SRC_ROOT/security/mfa.py" << 'EOF'
import os
import secrets
from typing import List

import pyotp
from argon2 import PasswordHasher

_ph = PasswordHasher()

def generate_mfa_secret() -> str:
    return pyotp.random_base32()

def get_totp(secret: str) -> pyotp.TOTP:
    return pyotp.TOTP(secret)

def verify_totp(secret: str, code: str) -> bool:
    totp = get_totp(secret)
    return totp.verify(code, valid_window=1)

def generate_recovery_codes(count: int = 8) -> List[str]:
    return [secrets.token_urlsafe(16) for _ in range(count)]

def hash_recovery_code(code: str) -> str:
    return _ph.hash(code)

def verify_recovery_code(code: str, hashed: str) -> bool:
    try:
        return _ph.verify(hashed, code)
    except Exception:
        return False
EOF

########################################
# 5. Admin sessions model (SQLAlchemy)
########################################
cat > "$SRC_ROOT/models/admin_session.py" << 'EOF'
from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, Column, DateTime, Integer, String, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base  # IMPORTANT: reuse existing Base

class AdminSession(Base):
    __tablename__ = "admin_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    jti = Column(String, unique=True, index=True, nullable=False)
    ip_address = Column(String, nullable=False)
    user_agent = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    revoked = Column(Boolean, default=False, nullable=False)

    user = relationship("User", backref="admin_sessions")
EOF

########################################
# 6. JSON audit logger (stdout + file hook)
########################################
cat > "$SRC_ROOT/audit/admin_audit.py" << 'EOF'
import json
import logging
import os
from datetime import datetime
from typing import Any, Dict, Optional

logger = logging.getLogger("admin_audit")
logger.setLevel(logging.INFO)

# stdout handler
_stdout_handler = logging.StreamHandler()
_stdout_handler.setLevel(logging.INFO)
logger.addHandler(_stdout_handler)

# optional file handler (fallback / local debug)
log_file = os.getenv("ADMIN_AUDIT_LOG_FILE")
if log_file:
    _file_handler = logging.FileHandler(log_file)
    _file_handler.setLevel(logging.INFO)
    logger.addHandler(_file_handler)

def _json_log(event: Dict[str, Any]) -> None:
    logger.info(json.dumps(event, default=str))

def log_admin_action(
    *,
    user_id: Optional[int],
    user_email: Optional[str],
    action: str,
    path: str,
    ip: str,
    user_agent: Optional[str] = None,
    meta: Optional[Dict[str, Any]] = None,
) -> None:
    event = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "user_id": user_id,
        "user_email": user_email,
        "action": action,
        "path": path,
        "ip": ip,
        "user_agent": user_agent,
        "meta": meta or {},
    }
    _json_log(event)
EOF

########################################
# 7. SECURITY TODO – MODEL FIELDS
########################################
cat > "$BACKEND_ROOT/scripts/security_model_todo.md" << 'EOF'
# SECURITY FREEZE LINE – MODEL FIELDS TO ADD (MANUALLY)

## users table – add columns

- failed_login_attempts: Integer, default 0, not null
- locked_until: TIMESTAMP WITH TIME ZONE, nullable
- last_login_at: TIMESTAMP WITH TIME ZONE, nullable
- last_login_ip: VARCHAR, nullable
- password_changed_at: TIMESTAMP WITH TIME ZONE, nullable
- mfa_enabled: BOOLEAN, default false, not null
- mfa_secret: VARCHAR, nullable
- recovery_codes_hash: TEXT, nullable
- created_by: VARCHAR, nullable
- updated_at: TIMESTAMP WITH TIME ZONE, default now(), not null
- deleted_at: TIMESTAMP WITH TIME ZONE, nullable

## admin_sessions table

Use src/models/admin_session.py as source of truth.

## Wiring (to be done in code):

- On login:
  - check is_account_locked(user)
  - on failure: register_failed_login(db, user)
  - on success: register_successful_login(db, user, ip)
  - create AdminSession row with jti, ip, user_agent, expires_at
  - log_admin_action(..., action="admin_login")

- On logout:
  - mark AdminSession.revoked = true
  - log_admin_action(..., action="admin_logout")

- On password change:
  - update password_hash
  - set password_changed_at = now()
  - log_admin_action(..., action="password_change")

- On MFA enable/disable:
  - manage mfa_secret, mfa_enabled, recovery_codes_hash
  - log_admin_action(..., action="mfa_update")

## IP extraction

Use src/security/ip_utils.get_client_ip(request) everywhere instead of request.client.host.

## Brute-force protection

Enforce MAX_FAILED_ATTEMPTS and LOCKOUT_MINUTES from src/security/login_security.py.
EOF

########################################
# 8. DEPENDENCIES HINT
########################################
echo
echo "[!] Install required Python deps in backend venv:"
echo "    pip install argon2-cffi pyotp"
echo
echo "=== DONE: SECURITY PRIMITIVES SCAFFOLDED (NO DESTRUCTIVE CHANGES) ==="
