#!/bin/bash

set -e

echo "🔧 Applying VC-grade Postgres Hardening..."

PGCONF="/var/lib/postgresql/data/postgresql.conf"

apply_setting() {
  SETTING=$1
  VALUE=$2
  if grep -q "^${SETTING}" "$PGCONF"; then
    sed -i "s/^${SETTING}.*/${SETTING} = ${VALUE}/" "$PGCONF"
  else
    echo "${SETTING} = ${VALUE}" >> "$PGCONF"
  fi
}

# Memory & Buffers
apply_setting "shared_buffers" "512MB"
apply_setting "work_mem" "64MB"
apply_setting "maintenance_work_mem" "256MB"

# WAL & Durability
apply_setting "wal_level" "replica"
apply_setting "max_wal_size" "2GB"
apply_setting "min_wal_size" "512MB"
apply_setting "synchronous_commit" "on"
apply_setting "full_page_writes" "on"
apply_setting "wal_compression" "on"

# Checkpoints
apply_setting "checkpoint_timeout" "15min"
apply_setting "checkpoint_completion_target" "0.9"

# Connections
apply_setting "max_connections" "200"
apply_setting "superuser_reserved_connections" "3"

# Logging
apply_setting "log_min_duration_statement" "500"
apply_setting "log_checkpoints" "on"
apply_setting "log_connections" "on"
apply_setting "log_disconnections" "on"

echo "🔄 Reloading Postgres configuration..."
psql -U predictora -c "SELECT pg_reload_conf();"

echo "✅ Postgres Hardening Applied Successfully."
