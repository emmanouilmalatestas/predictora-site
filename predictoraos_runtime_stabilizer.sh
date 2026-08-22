#!/bin/bash
# ============================================================
# PredictoraOS Runtime Stabilizer v2.0 (Hybrid Mode)
# Alerts + Risk Scoring + Proposed Fixes + Execution Gates
# Author: Emmanouil + Copilot
# ============================================================

EXEC_MODE=false
EXEC_CMD=""

# Parse execution flags
if [[ "$1" == "--exec" ]]; then
    EXEC_MODE=true
    EXEC_CMD="$2"
fi

echo ""
echo "============================================================"
echo "[PredictoraOS] Runtime Stabilizer v2.0 — Hybrid Mode"
echo "============================================================"
echo ""

# Utility: Alert function
alert() {
    local LEVEL=$1
    local COMPONENT=$2
    local MESSAGE=$3
    echo ""
    echo "[$LEVEL][$COMPONENT] $MESSAGE"
}

# Utility: Proposed fix
propose_fix() {
    local FIX=$1
    echo "Suggested fix: ./predictoraos_runtime_stabilizer.sh --exec $FIX"
}

# Utility: Execution gate
execute_if_requested() {
    local CMD=$1
    if $EXEC_MODE && [[ "$EXEC_CMD" == "$CMD" ]]; then
        echo "[EXEC] Running: $CMD"
        case $CMD in
            backend-restart)
                docker restart predictora-backend
                ;;
            restart-guardian)
                docker restart guardian-v2
                ;;
            restart-autoheal)
                docker restart autoheal-worker
                ;;
            restart-workers)
                docker restart revenue-exporter
                ;;
            restart-traefik)
                docker restart traefik
                ;;
            restart-redis)
                docker restart predictora-redis
                ;;
            restart-db)
                docker restart predictoraai-db
                ;;
            prune-images)
                docker system prune -af
                ;;
            optimize-backend-image)
                docker image prune -f
                ;;
            deep-clean)
                docker system prune -af --volumes
                ;;
            *)
                echo "[EXEC] Unknown command: $CMD"
                ;;
        esac
        echo "[EXEC] Completed."
        exit 0
    fi
}

# ------------------------------------------------------------
# BACKEND CHECK
# ------------------------------------------------------------

BACKEND_ID=$(docker ps --filter "name=predictora-backend" --format "{{.ID}}")

if [ -z "$BACKEND_ID" ]; then
    alert "FATAL" "BACKEND" "Backend container not running."
    propose_fix "backend-restart"
else
    HEALTH=$(docker inspect --format='{{json .State.Health.Status}}' $BACKEND_ID)
    if [[ "$HEALTH" != "\"healthy\"" ]]; then
        alert "FATAL" "BACKEND" "Backend unhealthy."
        propose_fix "backend-restart"
    else
        alert "OK" "BACKEND" "Backend healthy."
    fi
fi

execute_if_requested "backend-restart"

# ------------------------------------------------------------
# GUARDIAN CHECK
# ------------------------------------------------------------

GUARDIAN_ID=$(docker ps --filter "name=guardian-v2" --format "{{.ID}}")

if [ -z "$GUARDIAN_ID" ]; then
    alert "FATAL" "GUARDIAN" "Guardian not running."
    propose_fix "restart-guardian"
else
    ERRORS=$(docker logs --tail 50 guardian-v2 | grep -i "error")
    if [[ ! -z "$ERRORS" ]]; then
        alert "WARN" "GUARDIAN" "Guardian errors detected."
        propose_fix "restart-guardian"
    else
        alert "OK" "GUARDIAN" "Guardian stable."
    fi
fi

execute_if_requested "restart-guardian"

# ------------------------------------------------------------
# AUTOHEAL CHECK
# ------------------------------------------------------------

AUTOHEAL_ID=$(docker ps --filter "name=autoheal-worker" --format "{{.ID}}")

if [ -z "$AUTOHEAL_ID" ]; then
    alert "FATAL" "AUTOHEAL" "Autoheal not running."
    propose_fix "restart-autoheal"
else
    ERRORS=$(docker logs --tail 50 autoheal-worker | grep -i "404")
    if [[ ! -z "$ERRORS" ]]; then
        alert "WARN" "AUTOHEAL" "Autoheal hitting 404 (invalid restart endpoint)."
        propose_fix "restart-autoheal"
    else
        alert "OK" "AUTOHEAL" "Autoheal stable."
    fi
fi

execute_if_requested "restart-autoheal"

# ------------------------------------------------------------
# WORKERS CHECK
# ------------------------------------------------------------

WORKERS=$(docker ps --filter "name=revenue-exporter" --format "{{.Names}}")

for W in $WORKERS; do
    ERRORS=$(docker logs --tail 50 $W | grep -i "error")
    if [[ ! -z "$ERRORS" ]]; then
        alert "WARN" "WORKER" "$W has errors."
        propose_fix "restart-workers"
    else
        alert "OK" "WORKER" "$W stable."
    fi
done

execute_if_requested "restart-workers"

# ------------------------------------------------------------
# REDIS CHECK
# ------------------------------------------------------------

REDIS_ID=$(docker ps --filter "name=predictora-redis" --format "{{.ID}}")

if [ -z "$REDIS_ID" ]; then
    alert "FATAL" "REDIS" "Redis not running."
    propose_fix "restart-redis"
else
    PING=$(docker exec predictora-redis redis-cli ping)
    if [[ "$PING" != "PONG" ]]; then
        alert "FATAL" "REDIS" "Redis ping failed."
        propose_fix "restart-redis"
    else
        alert "OK" "REDIS" "Redis healthy."
    fi
fi

execute_if_requested "restart-redis"

# ------------------------------------------------------------
# DB CHECK
# ------------------------------------------------------------

DB_ID=$(docker ps --filter "name=predictoraai-db" --format "{{.ID}}")

if [ -z "$DB_ID" ]; then
    alert "FATAL" "DB" "DB not running."
    propose_fix "restart-db"
else
    RESULT=$(docker exec predictoraai-db psql -U predictora -c "SELECT 1;" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        alert "FATAL" "DB" "DB connection failed."
        propose_fix "restart-db"
    else
        alert "OK" "DB" "DB healthy."
    fi
fi

execute_if_requested "restart-db"

# ------------------------------------------------------------
# TRAEFIK CHECK
# ------------------------------------------------------------

TRAEFIK_ID=$(docker ps --filter "name=traefik" --format "{{.ID}}")

if [ -z "$TRAEFIK_ID" ]; then
    alert "FATAL" "TRAEFIK" "Traefik not running."
    propose_fix "restart-traefik"
else
    ERRORS=$(docker logs --tail 50 traefik | grep -i "error")
    if [[ ! -z "$ERRORS" ]]; then
        alert "WARN" "TRAEFIK" "Traefik errors detected."
        propose_fix "restart-traefik"
    else
        alert "OK" "TRAEFIK" "Traefik stable."
    fi
fi

execute_if_requested "restart-traefik"

# ------------------------------------------------------------
# IMAGE OPTIMIZATION (manual only)
# ------------------------------------------------------------

alert "INFO" "IMAGES" "Image optimization available."
propose_fix "prune-images"
propose_fix "optimize-backend-image"
propose_fix "deep-clean"

execute_if_requested "prune-images"
execute_if_requested "optimize-backend-image"
execute_if_requested "deep-clean"

echo ""
echo "============================================================"
echo "[PredictoraOS] Runtime Stabilizer v2.0 — COMPLETE"
echo "============================================================"
echo ""
