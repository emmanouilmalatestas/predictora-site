#!/usr/bin/env bash
set -euo pipefail

BACKEND="/home/deploy/predictoraai/backend"

echo "[+] Creating billing models"
cat > "$BACKEND/billing_models.py" << 'EOF'
from sqlalchemy import Column, String, Integer, Boolean, DateTime, Float
from datetime import datetime
from .database import Base


class Plan(Base):
    __tablename__ = "plans"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True)  # e.g. "basic", "pro", "enterprise"
    name = Column(String, nullable=False)
    monthly_price = Column(Float, nullable=False)
    request_limit_per_month = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_email = Column(String, index=True, nullable=False)
    plan_code = Column(String, nullable=False)
    stripe_customer_id = Column(String, nullable=True)
    stripe_subscription_id = Column(String, nullable=True)
    active = Column(Boolean, default=True)
    current_period_start = Column(DateTime, default=datetime.utcnow)
    current_period_end = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class ApiUsageMonthly(Base):
    __tablename__ = "api_usage_monthly"

    id = Column(Integer, primary_key=True, index=True)
    user_email = Column(String, index=True, nullable=False)
    month = Column(String, index=True, nullable=False)  # e.g. "2026-06"
    request_count = Column(Integer, default=0)
    last_updated = Column(DateTime, default=datetime.utcnow)
EOF

echo "[+] Writing migration notes for billing"
cat > "$BACKEND/BILLING_MIGRATION.txt" << 'EOF'
-- Plans
CREATE TABLE plans (
  id SERIAL PRIMARY KEY,
  code VARCHAR(64) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  monthly_price DOUBLE PRECISION NOT NULL,
  request_limit_per_month INT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Subscriptions
CREATE TABLE subscriptions (
  id SERIAL PRIMARY KEY,
  user_email VARCHAR(255) NOT NULL,
  plan_code VARCHAR(64) NOT NULL,
  stripe_customer_id VARCHAR(255),
  stripe_subscription_id VARCHAR(255),
  active BOOLEAN DEFAULT TRUE,
  current_period_start TIMESTAMP DEFAULT NOW(),
  current_period_end TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Monthly usage
CREATE TABLE api_usage_monthly (
  id SERIAL PRIMARY KEY,
  user_email VARCHAR(255) NOT NULL,
  month VARCHAR(16) NOT NULL,
  request_count INT DEFAULT 0,
  last_updated TIMESTAMP DEFAULT NOW()
);
EOF

echo "[+] Adding billing router"
cat > "$BACKEND/billing_router.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from .database import get_db
from .billing_models import Plan, Subscription, ApiUsageMonthly

router = APIRouter(prefix="/billing", tags=["billing"])


@router.get("/plans")
def list_plans(db: Session = Depends(get_db)):
    return {"plans": db.query(Plan).all()}


@router.post("/plans/seed")
def seed_plans(db: Session = Depends(get_db)):
    defaults = [
        {"code": "basic", "name": "Basic", "monthly_price": 19.0, "request_limit_per_month": 10000},
        {"code": "pro", "name": "Pro", "monthly_price": 49.0, "request_limit_per_month": 50000},
        {"code": "enterprise", "name": "Enterprise", "monthly_price": 199.0, "request_limit_per_month": 500000},
    ]
    for p in defaults:
        existing = db.query(Plan).filter(Plan.code == p["code"]).first()
        if not existing:
            db.add(Plan(**p))
    db.commit()
    return {"status": "ok"}


@router.post("/subscribe")
def subscribe(user_email: str, plan_code: str, db: Session = Depends(get_db)):
    plan = db.query(Plan).filter(Plan.code == plan_code).first()
    if not plan:
        raise HTTPException(status_code=400, detail="Invalid plan")

    sub = Subscription(
        user_email=user_email,
        plan_code=plan_code,
        active=True,
        current_period_start=datetime.utcnow(),
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return {"subscription": sub}


@router.get("/usage")
def get_usage(user_email: str, month: str, db: Session = Depends(get_db)):
    usage = db.query(ApiUsageMonthly).filter(
        ApiUsageMonthly.user_email == user_email,
        ApiUsageMonthly.month == month
    ).first()
    if not usage:
        usage = ApiUsageMonthly(user_email=user_email, month=month, request_count=0)
        db.add(usage)
        db.commit()
        db.refresh(usage)
    return {"usage": usage}


def increment_usage(db: Session, user_email: str, month: str):
    usage = db.query(ApiUsageMonthly).filter(
        ApiUsageMonthly.user_email == user_email,
        ApiUsageMonthly.month == month
    ).first()
    if not usage:
        usage = ApiUsageMonthly(user_email=user_email, month=month, request_count=0)
        db.add(usage)
    usage.request_count += 1
    usage.last_updated = datetime.utcnow()
    db.commit()
EOF

echo "[+] Wiring billing router into main.py"
MAIN="$BACKEND/main.py"

if ! grep -q "billing_router" "$MAIN"; then
  cat >> "$MAIN" << 'EOF'

# --- Billing / Monetization ---
from billing_router import router as billing_router

app.include_router(billing_router)
EOF
else
  echo "[!] billing_router already wired in main.py, skipping"
fi

echo "[+] Rebuilding backend with billing"
cd /home/deploy/predictoraai
docker compose build predictoraai-backend --no-cache
docker compose up -d

echo "[+] Phase 3 Monetization scaffolding complete."
echo "    - Apply BILLING_MIGRATION.txt to Postgres"
echo "    - Call /billing/plans/seed once"
echo "    - Use /billing/subscribe and /billing/usage from Admin UI or API"
