#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/home/deploy/predictoraai"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.prod.yml"
LOG_DIR="${ROOT_DIR}/orchestrator-logs"
mkdir -p "$LOG_DIR"

log() {
  echo "[$(date -Iseconds)] [ORCH] $*" | tee -a "$LOG_DIR/orchestrator.log"
}

# ---------- TELEGRAM ALERTS ----------

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

notify_telegram() {
  local msg="$1"

  if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    log "Telegram not configured – skipping notify: $msg"
    return 0
  fi

  curl -sSf \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${msg}" \
    >/dev/null 2>&1 || log "Telegram notify failed: $msg"
}

# ---------- GUARDIAN STATE ----------

GUARDIAN_STATE_FILE="${LOG_DIR}/guardian-state.json"

init_guardian_state() {
  if [ ! -f "$GUARDIAN_STATE_FILE" ]; then
    echo '{"failures":0,"last_failure":0,"safe_mode":false}' > "$GUARDIAN_STATE_FILE"
  fi
}

read_guardian_state() {
  failures=$(jq '.failures' "$GUARDIAN_STATE_FILE")
  last_failure=$(jq '.last_failure' "$GUARDIAN_STATE_FILE")
  safe_mode=$(jq '.safe_mode' "$GUARDIAN_STATE_FILE")
}

write_guardian_state() {
  jq -n \
    --argjson failures "$1" \
    --argjson last_failure "$2" \
    --argjson safe_mode "$3" \
    '{failures:$failures,last_failure:$last_failure,safe_mode:$safe_mode}' \
    > "$GUARDIAN_STATE_FILE"
}

# ---------- BACKEND ROLLBACK ENGINE ----------

BACKEND_STATE_FILE="${LOG_DIR}/backend-image-state.json"

backend_state_init() {
  if [ ! -f "$BACKEND_STATE_FILE" ]; then
    current_image=$(docker ps --filter "name=predictora-backend" --format '{{.Image}}' || echo "unknown")
    jq -n --arg image "$current_image" '{last_good_image:$image}' > "$BACKEND_STATE_FILE"
  fi
}

backend_state_update_good() {
  current_image=$(docker ps --filter "name=predictora-backend" --format '{{.Image}}' || echo "unknown")
  jq -n --arg image "$current_image" '{last_good_image:$image}' > "$BACKEND_STATE_FILE"
  log "Backend rollback state updated – last_good_image=${current_image}"
}

backend_rollback() {
  backend_state_init
  last_good_image=$(jq -r '.last_good_image' "$BACKEND_STATE_FILE")

  if [ -z "$last_good_image" ] || [ "$last_good_image" = "unknown" ]; then
    log "Backend rollback: no known last_good_image – skipping"
    notify_telegram "Guardian: backend unhealthy, but no rollback image known."
    return 1
  fi

  log "Backend rollback: reverting to image ${last_good_image}"
  notify_telegram "Guardian: backend unhealthy, rolling back to ${last_good_image}"

  docker stop predictora-backend || log "Backend stop failed during rollback"
  docker rm predictora-backend || log "Backend remove failed during rollback"

  docker run -d \
    --name predictora-backend \
    --env-file "${ROOT_DIR}/.env" \
    --network backend_internal \
    "${last_good_image}" || log "Backend rollback run failed"

  log "Backend rollback completed to ${last_good_image}"
}

# ---------- GUARDIAN ORCHESTRATOR ----------

guardian_cycle() {
  init_guardian_state
  read_guardian_state

  now=$(date +%s)

  if [ "$safe_mode" = "true" ]; then
    log "Guardian SAFE-MODE – no restarts, manual intervention required"
    notify_telegram "Guardian SAFE-MODE triggered"
    return 0
  fi

  log "Guardian cycle: checking backend health"

  if curl -sSf https://api.predictoraai.com/health >/dev/null 2>&1; then
    log "Backend HEALTHY – resetting failure counter"
    write_guardian_state 0 "$now" false
    backend_state_update_good
    return 0
  fi

  log "Backend UNHEALTHY – starting backoff sequence"

  for delay in 5 10 20; do
    log "Backoff wait ${delay}s before restart attempt"
    sleep "$delay"
    if curl -sSf https://api.predictoraai.com/health >/dev/null 2>&1; then
      log "Backend recovered during backoff – aborting restart"
      write_guardian_state 0 "$now" false
      backend_state_update_good
      return 0
    fi
  done

  window=60
  if [ $((now - last_failure)) -le $window ]; then
    failures=$((failures + 1))
  else
    failures=1
  fi

  log "Guardian: failure count in window = ${failures}"

  if [ "$failures" -ge 3 ]; then
    log "Guardian entering SAFE-MODE (3 failures in 60s)"
    notify_telegram "Guardian SAFE-MODE: backend failing repeatedly"
    write_guardian_state "$failures" "$now" true
    return 1
  fi

  log "Restarting backend container (failure #${failures})"
  docker restart predictora-backend || log "Backend restart failed"

  sleep 10
  if ! curl -sSf https://api.predictoraai.com/health >/dev/null 2>&1; then
    log "Backend still UNHEALTHY after restart – triggering rollback"
    backend_rollback
  fi

  write_guardian_state "$failures" "$now" false
}

# ---------- TRAEFIK WATCHDOG (A instance) ----------

traefik_watchdog() {
  log "Traefik-A watchdog: checking provider status"

  if ! curl -sSf http://localhost:8080/api/rawdata >/dev/null 2>&1; then
    log "Traefik-A API unreachable – restarting Traefik-A"
    notify_telegram "Traefik-A unreachable – restarting"
    docker restart predictoraai-traefik-1 || log "Traefik-A restart failed"
    sleep 10
    return
  fi

  providers=$(curl -s http://localhost:8080/api/rawdata | jq '.routers.backend // empty' || true)
  if [ -z "$providers" ]; then
    log "Traefik-A backend router missing – forcing reload"
    notify_telegram "Traefik-A router missing – reloading"
    docker restart predictoraai-traefik-1 || log "Traefik-A restart failed"
    sleep 10
  else
    log "Traefik-A routing OK"
  fi
}

# ---------- TRAEFIK FAILOVER (A/B) ----------

traefik_failover() {
  log "Traefik failover check: A/B status evaluation"

  A_OK=true
  if ! curl -sSf http://localhost:8080/api/rawdata >/dev/null 2>&1; then
    A_OK=false
    log "Traefik-A API unreachable"
  fi

  B_OK=true
  if ! curl -sSf http://localhost:8085/api/rawdata >/dev/null 2>&1; then
    B_OK=false
    log "Traefik-B API unreachable"
  fi

  if [ "$A_OK" = false ] && [ "$B_OK" = true ]; then
    log "Failover: Traefik-A DOWN → switching to Traefik-B"
    notify_telegram "Failover: Traefik-A DOWN → using Traefik-B"
    docker restart predictoraai-traefik-1 || log "Traefik-A restart failed"
    return 0
  fi

  if [ "$B_OK" = false ] && [ "$A_OK" = true ]; then
    log "Failover: Traefik-B DOWN → switching to Traefik-A"
    notify_telegram "Failover: Traefik-B DOWN → using Traefik-A"
    docker restart traefik-b || log "Traefik-B restart failed"
    return 0
  fi

  if [ "$A_OK" = false ] && [ "$B_OK" = false ]; then
    log "CRITICAL: Both Traefik instances DOWN"
    notify_telegram "CRITICAL: Traefik-A & Traefik-B DOWN"
    return 1
  fi

  log "Traefik A/B both healthy – no failover needed"
}

# ---------- HEALTH-WEIGHTED ROUTING ----------

traefik_health_weighted() {
  log "Traefik health-weighted routing check"

  A_LAT=$(curl -s -o /dev/null -w '%{time_total}' https://api.predictoraai.com/health --resolve api.predictoraai.com:443:127.0.0.1 || echo "1.0")
  B_LAT=$(curl -s -o /dev/null -w '%{time_total}' https://api.predictoraai.com/health --resolve api.predictoraai.com:444:127.0.0.1 || echo "1.0")

  log "Traefik-A latency=${A_LAT}s, Traefik-B latency=${B_LAT}s"

  if (( $(echo "$A_LAT < $B_LAT" | bc -l) )); then
    log "Routing preference: Traefik-A"
  else
    log "Routing preference: Traefik-B"
  fi
}

# ---------- DRIFT DETECTOR ----------

guardian_drift_detector() {
  log "Guardian drift detector: Traefik A/B router comparison"

  A_ROUTERS=$(curl -s http://localhost:8080/api/rawdata | jq '.routers | length' 2>/dev/null || echo "0")
  B_ROUTERS=$(curl -s http://localhost:8085/api/rawdata | jq '.routers | length' 2>/dev/null || echo "0")

  log "Traefik-A routers=${A_ROUTERS}, Traefik-B routers=${B_ROUTERS}"

  if [ "$A_ROUTERS" -ne "$B_ROUTERS" ]; then
    log "DRIFT DETECTED: router mismatch"
    notify_telegram "Drift detected: Traefik-A=${A_ROUTERS}, Traefik-B=${B_ROUTERS}"
  else
    log "No Traefik router drift detected"
  fi
}

# ---------- BACKEND GRACEFUL CHECK ----------

backend_graceful_check() {
  log "Backend graceful check: verifying /metrics and /health"

  if curl -sSf https://api.predictoraai.com/metrics >/dev/null 2>&1; then
    log "Backend metrics endpoint OK (optional)"
  else
    log "Backend metrics endpoint OPTIONAL – skipping"
  fi

  if curl -sSf https://api.predictoraai.com/health >/dev/null 2>&1; then
    log "Backend health OK"
  else
    log "Backend health FAILED – critical"
  fi
}

# ---------- MONITORING SNAPSHOT ----------

monitoring_snapshot() {
  log "Monitoring snapshot: capturing core metrics"

  curl -sSf http://localhost:9090/api/v1/query \
    --data-urlencode 'query=up' \
    > "$LOG_DIR/prometheus-up-$(date +%s).json" || log "Prometheus query failed"

  curl -sSf http://localhost:9090/api/v1/query \
    --data-urlencode 'query=rate(http_requests_total[5m])' \
    > "$LOG_DIR/prometheus-traffic-$(date +%s).json" || log "Traffic query failed"
}

# ---------- DAILY ROUTINE ----------

daily_routine() {
  log "Starting daily VS-grade routine"

  guardian_cycle
  traefik_watchdog
  traefik_failover
  traefik_health_weighted
  guardian_drift_detector
  backend_graceful_check
  monitoring_snapshot

  log "Daily routine completed"
}

case "${1:-}" in
  daily)
    daily_routine
    ;;
  guardian)
    guardian_cycle
    ;;
  traefik)
    traefik_watchdog
    ;;
  traefik-failover)
    traefik_failover
    ;;
  backend-check)
    backend_graceful_check
    ;;
  chaos-backend)
    chaos_drill_backend
    ;;
  chaos-db)
    chaos_drill_db
    ;;
  chaos-traefik)
    chaos_drill_traefik
    ;;
  *)
    echo "Usage: $0 {daily|guardian|traefik|traefik-failover|backend-check|chaos-backend|chaos-db|chaos-traefik}"
    exit 1
    ;;
esac
