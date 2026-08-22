#!/bin/bash
set -e

ROOT_DIR="$(pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.prod.yml"
MONITORING_COMPOSE="$ROOT_DIR/infra/monitoring/docker-compose.monitoring.yml"
ADMIN_DIR="$ROOT_DIR/apps/admin"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/apps/client"
WEBHOOK_DIR="$ROOT_DIR/services/webhook"
REVENUE_EXPORTER_DIR="$ROOT_DIR/backend"
REDIS_DIR="$ROOT_DIR/infra/docker"
LOGFILE="$ROOT_DIR/setup_infra.log"

echo "=== PredictoraAI Infrastructure Setup ===" | tee -a $LOGFILE
echo "Root: $ROOT_DIR" | tee -a $LOGFILE

###############################################
# STEP 1 — CHECK DOCKER HEALTH
###############################################
echo "[1/10] Checking Docker..." | tee -a $LOGFILE
docker info >/dev/null 2>&1 || { echo "Docker not running"; exit 1; }

###############################################
# STEP 2 — STOP ALL RUNNING STACKS
###############################################
echo "[2/10] Stopping existing containers..." | tee -a $LOGFILE
docker compose -f $COMPOSE_FILE down || true
docker compose -f $MONITORING_COMPOSE down || true

###############################################
# STEP 3 — CLEANUP OLD CONTAINERS
###############################################
echo "[3/10] Cleaning old containers..." | tee -a $LOGFILE
docker system prune -f

###############################################
# STEP 4 — BUILD ADMIN PANEL
###############################################
echo "[4/10] Building admin panel..." | tee -a $LOGFILE
cd $ADMIN_DIR
npm install --legacy-peer-deps
npm run build
cd $ROOT_DIR

###############################################
# STEP 5 — BUILD FRONTEND
###############################################
echo "[5/10] Building frontend..." | tee -a $LOGFILE
cd $FRONTEND_DIR
npm install --legacy-peer-deps
npm run build
cd $ROOT_DIR

###############################################
# STEP 6 — BUILD BACKEND DOCKER IMAGE
###############################################
echo "[6/10] Building backend Docker image..." | tee -a $LOGFILE
docker compose -f $COMPOSE_FILE build predictora-backend

###############################################
# STEP 7 — START CORE STACK
###############################################
echo "[7/10] Starting core production stack..." | tee -a $LOGFILE
docker compose -f $COMPOSE_FILE up -d --build

###############################################
# STEP 8 — START MONITORING STACK
###############################################
echo "[8/10] Starting monitoring stack..." | tee -a $LOGFILE
docker compose -f $MONITORING_COMPOSE up -d --build

###############################################
# STEP 9 — HEALTH CHECKS
###############################################
echo "[9/10] Running health checks..." | tee -a $LOGFILE

check_url() {
  URL=$1
  NAME=$2
  echo "Checking $NAME at $URL" | tee -a $LOGFILE
  for i in {1..10}; do
    if curl -s --head $URL | grep "200 OK" > /dev/null; then
      echo "$NAME OK" | tee -a $LOGFILE
      return
    fi
    sleep 3
  done
  echo "$NAME FAILED" | tee -a $LOGFILE
  exit 1
}

check_url "https://api.predictoraai.com/health" "Backend API"
check_url "https://predictoraai.com" "Frontend"
check_url "https://admin.predictoraai.com" "Admin Panel"
check_url "https://monitoring.predictoraai.com" "Monitoring"
check_url "https://grafana.predictoraai.com" "Grafana"
check_url "https://loki.predictoraai.com" "Loki"
check_url "https://prometheus.predictoraai.com" "Prometheus"

###############################################
# STEP 10 — SUCCESS
###############################################
echo "[10/10] PredictoraAI Infrastructure is LIVE" | tee -a $LOGFILE
echo "============================================" | tee -a $LOGFILE
echo "All systems operational." | tee -a $LOGFILE
