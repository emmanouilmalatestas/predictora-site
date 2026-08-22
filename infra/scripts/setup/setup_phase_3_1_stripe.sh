#!/usr/bin/env bash
set -euo pipefail

BACKEND="/home/deploy/predictoraai/backend"

echo "[+] Creating Stripe subscription sync module"
cat > "$BACKEND/stripe_subscription_sync.py" << 'EOF'
import stripe
import os
from sqlalchemy.orm import Session
from datetime import datetime
from .billing_models import Subscription, Plan

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

def sync_subscription_from_stripe(db: Session, stripe_sub_id: str):
    sub = stripe.Subscription.retrieve(stripe_sub_id)

    customer_id = sub["customer"]
    plan_code = sub["items"]["data"][0]["price"]["nickname"]  # e.g. "basic", "pro"
    status = sub["status"]
    current_start = datetime.fromtimestamp(sub["current_period_start"])
    current_end = datetime.fromtimestamp(sub["current_period_end"])

    # Find local subscription
    local = db.query(Subscription).filter(
        Subscription.stripe_subscription_id == stripe_sub_id
    ).first()

    if not local:
        # Create new subscription
        local = Subscription(
            user_email=sub["metadata"].get("user_email", "unknown"),
            plan_code=plan_code,
            stripe_customer_id=customer_id,
            stripe_subscription_id=stripe_sub_id,
            active=(status == "active"),
            current_period_start=current_start,
            current_period_end=current_end,
        )
        db.add(local)
    else:
        # Update existing
        local.plan_code = plan_code
        local.active = (status == "active")
        local.current_period_start = current_start
        local.current_period_end = current_end

    db.commit()
    return local
EOF


echo "[+] Adding Stripe webhook router for subscription events"
cat > "$BACKEND/stripe_billing_webhook.py" << 'EOF'
import os
import stripe
from fastapi import APIRouter, Request, Depends, HTTPException
from sqlalchemy.orm import Session
from .database import get_db
from .stripe_subscription_sync import sync_subscription_from_stripe

router = APIRouter(prefix="/stripe/billing", tags=["stripe-billing"])

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
WEBHOOK_SECRET = os.getenv("STRIPE_BILLING_WEBHOOK_SECRET")

@router.post("/webhook")
async def stripe_billing_webhook(request: Request, db: Session = Depends(get_db)):
    payload = await request.body()
    sig = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig, WEBHOOK_SECRET
        )
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid signature")

    event_type = event["type"]

    # Subscription events
    if event_type in [
        "customer.subscription.created",
        "customer.subscription.updated",
        "customer.subscription.deleted",
    ]:
        stripe_sub_id = event["data"]["object"]["id"]
        local = sync_subscription_from_stripe(db, stripe_sub_id)
        return {"status": "synced", "subscription": local.id}

    return {"status": "ignored", "event": event_type}
EOF


echo "[+] Wiring Stripe billing webhook into main.py"
MAIN="$BACKEND/main.py"

if ! grep -q "stripe_billing_webhook" "$MAIN"; then
  cat >> "$MAIN" << 'EOF'

# --- Stripe Billing Webhook ---
from stripe_billing_webhook import router as stripe_billing_webhook
app.include_router(stripe_billing_webhook)
EOF
else
  echo "[!] Stripe billing webhook already wired, skipping"
fi


echo "[+] Rebuilding backend"
cd /home/deploy/predictoraai
docker compose build predictoraai-backend --no-cache
docker compose up -d

echo "[+] Phase 3.1 Stripe subscription sync complete."
echo "    IMPORTANT:"
echo "    - Add STRIPE_BILLING_WEBHOOK_SECRET to .env"
echo "    - Set Stripe webhook to: https://api.predictoraai.com/stripe/billing/webhook"
