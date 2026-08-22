import time
import json
import logging
import queue
from datetime import datetime

import requests

# -----------------------------
# CONFIG
# -----------------------------

BILLING_BASE = "https://api.predictoraai.com/billing"
STRIPE_API = "https://api.stripe.com/v1/subscription_items"

STRIPE_KEY = "sk_live_xxxxxxxxxxxxxxxxxxxxx"

MAX_RETRIES = 5
INITIAL_BACKOFF = 0.5  # seconds
BACKOFF_FACTOR = 2.0

# DLQ (in‑memory, μπορείς να το κάνεις file/Redis/SQS)
DLQ = queue.Queue()

# -----------------------------
# LOGGING
# -----------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

logger = logging.getLogger("WARZONE_BILLING_BRIDGE")


def now_ts():
    return int(time.time())


def now_iso():
    return datetime.utcnow().isoformat()


# -----------------------------
# GENERIC RETRY WRAPPER
# -----------------------------

def http_post_with_retry(url, *, json_payload=None, form_payload=None, auth=None, max_retries=MAX_RETRIES):
    attempt = 0
    backoff = INITIAL_BACKOFF

    while True:
        attempt += 1
        try:
            if json_payload is not None:
                r = requests.post(url, json=json_payload, timeout=10)
            else:
                r = requests.post(url, data=form_payload, auth=auth, timeout=10)

            if 200 <= r.status_code < 300:
                logger.info("HTTP POST OK %s (status=%s)", url, r.status_code)
                return r

            logger.warning("HTTP POST FAILED %s (status=%s, body=%s)", url, r.status_code, r.text)

        except Exception as e:
            logger.error("HTTP POST EXCEPTION %s: %s", url, e)

        if attempt >= max_retries:
            logger.error("MAX RETRIES REACHED for %s, sending to DLQ", url)
            DLQ.put({
                "url": url,
                "json_payload": json_payload,
                "form_payload": form_payload,
                "auth": bool(auth),
                "timestamp": now_iso(),
            })
            return None

        logger.info("Retrying %s in %.2f seconds (attempt %d/%d)", url, backoff, attempt, max_retries)
        time.sleep(backoff)
        backoff *= BACKOFF_FACTOR


# -----------------------------
# 1. USAGE INTEGRATION
# -----------------------------

def send_usage(tenant_id, event, amount):
    payload = {
        "tenant_id": tenant_id,
        "event": event,
        "amount": amount,
        "timestamp": now_iso(),
    }

    url = f"{BILLING_BASE}/usage"
    logger.info("Usage → Billing: %s %s", url, payload)
    return http_post_with_retry(url, json_payload=payload)


# -----------------------------
# 2. ALERTS INTEGRATION
# -----------------------------

def send_alert(tenant_id, alert_type, details):
    payload = {
        "tenant_id": tenant_id,
        "alert": alert_type,
        "details": details,
        "timestamp": now_iso(),
    }

    url = f"{BILLING_BASE}/alert"
    logger.info("Alert → Billing: %s %s", url, payload)
    return http_post_with_retry(url, json_payload=payload)


# -----------------------------
# 3. ENFORCEMENT INTEGRATION
# -----------------------------

def enforce_action(tenant_id, action, limit=None, plan=None):
    payload = {
        "tenant_id": tenant_id,
        "action": action,
        "timestamp": now_iso(),
    }

    if limit is not None:
        payload["limit"] = limit
    if plan is not None:
        payload["plan"] = plan

    url = f"{BILLING_BASE}/enforce"
    logger.info("Enforce → Billing: %s %s", url, payload)
    return http_post_with_retry(url, json_payload=payload)


# -----------------------------
# 4. STRIPE USAGE INTEGRATION
# -----------------------------

def send_stripe_usage(subscription_item_id, quantity):
    payload = {
        "quantity": quantity,
        "timestamp": now_ts(),
        "action": "increment",
    }

    url = f"{STRIPE_API}/{subscription_item_id}/usage_records"
    logger.info("Usage → Stripe: %s %s", url, payload)
    return http_post_with_retry(url, form_payload=payload, auth=(STRIPE_KEY, ""))


# -----------------------------
# DLQ DRAIN (optional)
# -----------------------------

def drain_dlq():
    logger.info("Draining DLQ...")
    while not DLQ.empty():
        item = DLQ.get()
        logger.warning("DLQ ITEM: %s", json.dumps(item))


# -----------------------------
# DEMO / SMOKE TEST
# -----------------------------

if __name__ == "__main__":
    tenant = "tenant_123"

    send_usage(tenant, "api_call", 1)
    send_usage(tenant, "tokens", 1532)
    send_usage(tenant, "compute_ms", 87)

    send_alert(tenant, "quota_exceeded", {"quota": 100000, "usage": 120000})

    enforce_action(tenant, "throttle", limit=10)
    enforce_action(tenant, "upgrade", plan="pro")

    send_stripe_usage("si_123456789", 1532)

    drain_dlq()
