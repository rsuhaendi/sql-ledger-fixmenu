#!/usr/bin/env bash
set -euo pipefail

# Restore SQL-Ledger backup created by scripts/backup.sh
# Usage: sudo bash scripts/restore.sh /var/backups/sql-ledger/YYYYMMDD-HHMMSS

APP_DIR="${APP_DIR:-/sql-ledger}"
DB_NAME="${DB_NAME:-ledger}"
DB_ROLE="${DB_ROLE:-sql-ledger}"
BACKUP_DIR="${1:-}"

if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
  echo "Usage: sudo bash scripts/restore.sh /path/to/backup-dir" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

systemctl stop apache2 || true

sudo -u postgres dropdb --if-exists "$DB_NAME"
sudo -u postgres createdb -O "$DB_ROLE" -E UTF8 -T template0 "$DB_NAME"
sudo -u postgres pg_restore -d "$DB_NAME" --no-owner --role="$DB_ROLE" "$BACKUP_DIR/${DB_NAME}.dump"

tar -xzf "$BACKUP_DIR/sql-ledger-app.tar.gz" -C "$APP_DIR"
chown -R www-data:www-data "$APP_DIR"
chmod 711 "$APP_DIR/users" "$APP_DIR/templates" "$APP_DIR/spool" || true

systemctl start apache2
echo "Restore complete. Ctrl+F5 in browser."
