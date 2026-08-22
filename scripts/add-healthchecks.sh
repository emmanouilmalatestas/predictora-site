#!/bin/bash

set -e

COMPOSE_FILE="/home/deploy/predictoraai/docker-compose.yml"
BACKUP_FILE="/home/deploy/predictoraai/docker-compose.yml.bak.$(date +%s)"

echo "[+] Creating backup: $BACKUP_FILE"
cp "$COMPOSE_FILE" "$BACKUP_FILE"

echo "[+] Injecting VS-grade healthchecks..."

# Backend
yq e -i '
.services.predictoraai-backend.healthcheck = {
    "test": ["CMD", "curl", "-f", "http://localhost:8000/api/health"],
    "interval": "10s",
    "timeout": "3s",
    "retries": 5,
    "start_period": "10s"
  }
' "$COMPOSE_FILE"

# Admin Frontend
yq e -i '
  .services.predictoraai-admin-frontend.healthcheck = {
    "test": ["CMD", "curl", "-f", "http://localhost:3001"],
    "interval": "10s",
    "timeout": "3s",
    "retries": 5,
    "start_period": "10s"
  }
' "$COMPOSE_FILE"

# Stripe Webhook
yq e -i '
  .services.stripe-webhook.healthcheck = {
    "test": ["CMD", "curl", "-f", "http://localhost:3002/health"],
    "interval": "10s",
    "timeout": "3s",
    "retries": 5,
    "start_period": "10s"
  }
' "$COMPOSE_FILE"

# Postgres
yq e -i '
  .services.predictoraai-db.healthcheck = {
    "test": ["CMD-SHELL", "pg_isready -U postgres"],
    "interval": "10s",
    "timeout": "5s",
    "retries": 5,
    "start_period": "20s"
  }
' "$COMPOSE_FILE"

echo "[+] Healthchecks injected successfully."
echo "[+] Validate with: docker compose config"
