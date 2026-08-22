import time
import requests
import socket
import subprocess
from collections import deque

PROM = "http://prometheus:9090"

# Loki endpoint
LOKI = "http://loki:3100/loki/api/v1/push"

# Telegram credentials
TELEGRAM_TOKEN = "8791478475:AAFtHlA7Q7Wn8gwAPcNBPSA0q_YV2GqFKuk"
TELEGRAM_CHAT_ID = "7747676404"

# Prometheus pushgateway
PUSH = "http://pushgateway:9091/metrics/job/guardian_v2"

restart_history = deque(maxlen=5)


def log(msg):
    ts = int(time.time() * 1000)
    print(msg)

    # Loki logging
    try:
        payload = {
            "streams": [
                {
                    "stream": {"app": "guardian-v2"},
                    "values": [[str(ts * 1000000), msg]]
                }
            ]
        }
        requests.post(LOKI, json=payload, timeout=3)
    except:
        pass


LAST_TELEGRAM = 0

def telegram(msg):
    global LAST_TELEGRAM
    now = time.time()

    # Rate limit: max 1 message per 60 seconds
    if now - LAST_TELEGRAM < 60:
        return

    LAST_TELEGRAM = now

    try:
        requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
            json={"chat_id": TELEGRAM_CHAT_ID, "text": msg},
            timeout=5
        )
    except Exception as e:
        log(f"[GUARDIAN-V2] Telegram error: {e}")

def push_metric(name, value):
    try:
        requests.post(PUSH, data=f"{name} {value}\n", timeout=3)
    except:
        pass


log("[GUARDIAN-V2] Starting guardian...")
log("[GUARDIAN-V2] Waiting for Prometheus...")
time.sleep(3)

def healthy():
    try:
        r = requests.get("http://predictora-backend:8000/health", timeout=5)
        if r.status_code == 200:
            push_metric("guardian_backend_up", 1)
            return True
        else:
            push_metric("guardian_backend_up", 0)
            return False
    except Exception as e:
        log(f"[GUARDIAN-V2] Health check error: {e}")
        push_metric("guardian_health_errors", 1)
        return False

def restart():
    now = time.time()
    restart_history.append(now)

    if len(restart_history) == 5 and (now - restart_history[0]) < 300:
        msg = "[GUARDIAN-V2] RATE LIMIT: Too many restarts → PAUSE"
        log(msg)
        telegram(msg)
        push_metric("guardian_rate_limit", 1)
        return

    try:
        # Ask autoheal-worker to restart backend
        r = requests.post("http://autoheal-worker:5000/alert", timeout=5)
        if r.status_code == 200:
            msg = "[GUARDIAN-V2] Restarted backend via autoheal-worker"
            log(msg)
            telegram(msg)
            push_metric("guardian_restarts", now)
        else:
            raise Exception(f"Autoheal error: {r.text}")

    except Exception as e:
        msg = f"[GUARDIAN-V2] Restart failed (autoheal-worker): {e}"
        log(msg)
        telegram(msg)
        push_metric("guardian_restart_failures", 1)


def self_health():
    try:
        socket.gethostbyname("prometheus")
        push_metric("guardian_self_health", 1)
        return True
    except:
        push_metric("guardian_self_health", 0)
        return False


def loop():
    log("[GUARDIAN-V2] Entering loop...")
    telegram("Guardian-V2 started successfully")

    while True:
        if not self_health():
            log("[GUARDIAN-V2] Self-health failed (DNS/network)")
            telegram("Guardian-V2 self-health failure")
            time.sleep(5)
            continue

        if healthy():
            log("[GUARDIAN-V2] Health OK")
        else:
            log("[GUARDIAN-V2] Backend unhealthy → restart")
            restart()

        time.sleep(10)


if __name__ == "__main__":
    loop()
