import os
import requests

LIVE_KEY = os.getenv("STRIPE_LIVE_KEY")
LIVE_WHSEC = os.getenv("STRIPE_LIVE_WEBHOOK_SECRET")

def mask(s):
    if not s:
        return "None"
    return s[:8] + "..." + s[-4:]

print("\n=== STRIPE HEALTHCHECK (LIVE MODE) ===\n")

print("Loaded STRIPE_LIVE_KEY:        ", mask(LIVE_KEY))
print("Loaded STRIPE_LIVE_WEBHOOK_SECRET:", mask(LIVE_WHSEC))

if not LIVE_KEY or not LIVE_WHSEC:
    print("\nFAIL ❌  Missing required environment variables.\n")
    exit(1)

# 1) LIVE API CALL
print("\n1) Checking LIVE API key validity...")
r = requests.get(
    "https://api.stripe.com/v1/accounts",
    auth=(LIVE_KEY, "")
)

if r.status_code == 200:
    account_id = r.json().get("id")
    print("PASS ✅  Valid LIVE key. Account:", account_id)
else:
    print("FAIL ❌  Invalid LIVE key:", r.text)
    exit(1)

# 2) FETCH WEBHOOK ENDPOINTS
print("\n2) Fetching webhook endpoints...")
r = requests.get(
    "https://api.stripe.com/v1/webhook_endpoints",
    auth=(LIVE_KEY, "")
)

if r.status_code != 200:
    print("FAIL ❌  Cannot fetch webhook endpoints:", r.text)
    exit(1)

endpoints = r.json().get("data", [])
target_url = "https://webhook.predictoraai.com/stripe/webhook"

found = None
for ep in endpoints:
    if ep.get("url") == target_url:
        found = ep
        break

if not found:
    print("FAIL ❌  Production webhook endpoint NOT found in Stripe.")
    exit(1)

print("PASS ✅  Found production webhook endpoint.")

# 3) VERIFY WHSEC MATCH
stripe_whsec = found.get("secret")

print("\n3) Checking webhook secret match...")
print("Container WHSEC:", mask(LIVE_WHSEC))
print("Stripe WHSEC:   ", mask(stripe_whsec))

if LIVE_WHSEC == stripe_whsec:
    print("PASS ✅  Webhook secret matches Stripe.")
else:
    print("FAIL ❌  Webhook secret mismatch!")
    exit(1)

print("\n=== ALL CHECKS PASSED — STRIPE LIVE CONFIG IS HEALTHY ✅ ===\n")
