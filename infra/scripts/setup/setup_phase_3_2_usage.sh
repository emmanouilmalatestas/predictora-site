#!/usr/bin/env bash
set -euo pipefail

BACKEND="/home/deploy/predictoraai/backend"

echo "[+] Creating usage_billing.py (core logic)"
cat > "$BACKEND/usage_billing.py" << 'EOF'
from datetime import datetime
from sqlalchemy.orm import Session
from .billing_models import ApiUsageMonthly, Subscription, Plan

def current_month_str() -> str:
    now = datetime.utcnow()
    return f"{now.year}-{now.month:02d}"

def get_active_subscription(db: Session, user_email: str):
    return (
        db.query(Subscription)
        .filter(Subscription.user_email == user_email, Subscription.active == True)
        .first()
    )

def get_plan(db: Session, plan_code: str):
    return db.query(Plan).filter(Plan.code == plan_code).first()

def increment_and_check_usage(db: Session, user_email: str):
    month = current_month_str()

    sub = get_active_subscription(db, user_email)
    if not sub:
        return False, "No active subscription"

    plan = get_plan(db, sub.plan_code)
    if not plan:
        return False, "Plan not found"

    usage = (
        db.query(ApiUsageMonthly)
        .filter(ApiUsageMonthly.user_email == user_email, ApiUsageMonthly.month == month)
        .first()
    )

    if not usage:
        usage = ApiUsageMonthly(
            user_email=user_email,
            month=month,
            request_count=0,
            last_updated=datetime.utcnow(),
        )
        db.add(usage)

    # Check before increment
    if usage.request_count >= plan.request_limit_per_month:
        return False, "Usage limit exceeded"

    usage.request_count += 1
    usage.last_updated = datetime.utcnow()
    db.commit()
    return True, {
        "month": month,
        "request_count": usage.request_count,
        "limit": plan.request_limit_per_month,
        "plan": plan.code,
    }
EOF

echo "[+] Adding usage middleware dependency"
cat > "$BACKEND/deps_usage.py" << 'EOF'
from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session
from .database import get_db
from .usage_billing import increment_and_check_usage

def enforce_usage(user_email: str, db: Session = Depends(get_db)):
  ok, info = increment_and_check_usage(db, user_email)
  if not ok:
      raise HTTPException(status_code=402, detail=str(info))
  return info
EOF

echo "[+] Adding admin usage router"
cat > "$BACKEND/admin_usage_router.py" << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from .database import get_db
from .billing_models import ApiUsageMonthly

router = APIRouter(prefix="/admin/usage", tags=["admin-usage"])

@router.get("/monthly")
def list_monthly_usage(db: Session = Depends(get_db)):
    rows = db.query(ApiUsageMonthly).all()
    return {"usage": rows}
EOF

echo "[+] Wiring admin_usage_router into main.py"
MAIN="$BACKEND/main.py"

if ! grep -q "admin_usage_router" "$MAIN"; then
  cat >> "$MAIN" << 'EOF'

# --- Admin Usage Router ---
from admin_usage_router import router as admin_usage_router
app.include_router(admin_usage_router)
EOF
else
  echo "[!] admin_usage_router already wired, skipping"
fi

echo "[+] NOTE: You must manually plug enforce_usage() into protected endpoints."
echo "Example inside a FastAPI route:"
echo ""
echo "  from deps_usage import enforce_usage"
echo ""
echo "  @app.get('/predictions')"
echo "  def predictions(user=Depends(get_current_user), usage=Depends(lambda db=Depends(get_db): enforce_usage(user.email, db))):"
echo "      ..."
echo ""
echo "[+] Rebuilding backend"
cd /home/deploy/predictoraai
docker compose build predictoraai-backend --no-cache
docker compose up -d

echo "[+] Phase 3.2 Usage Billing Engine scaffolding complete."
echo "    - Wire enforce_usage() into the endpoints you θέλεις να χρεώνονται."
echo "    - Admin can see usage at: GET /admin/usage/monthly"
