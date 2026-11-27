#!/usr/bin/env bash
set -euo pipefail

# Backup SQL-Ledger app config, users, templates, spool, and PostgreSQL DB.
# Run as root or a user with postgres/read access.

APP_DIR="${APP_DIR:-/sql-ledger}"
DB_NAME="${DB_NAME:-ledger}"
DB_USER="${DB_USER:-sql-ledger}"
OUT_DIR="${OUT_DIR:-/var/backups/sql-ledger}"
TS="$(date +%Y%m%d-%H%M%S)"
DEST="$OUT_DIR/$TS"

mkdir -p "$DEST"
cd "$APP_DIR"

# DB dump (custom format). Adjust auth as needed.
sudo -u postgres pg_dump -Fc "$DB_NAME" > "$DEST/${DB_NAME}.dump"

# App/config backup. users/ contains credentials - keep backup private.
tar -czf "$DEST/sql-ledger-app.tar.gz" \
  --exclude='.git' \
  --exclude='*.log' \
  sql-ledger.conf users templates spool menu.ini config scripts sql

chmod -R go-rwx "$DEST"
echo "Backup created: $DEST"
