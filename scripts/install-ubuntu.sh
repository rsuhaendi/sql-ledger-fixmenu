#!/usr/bin/env bash
set -euo pipefail

# SQL-Ledger install helper for Ubuntu/Debian (fresh server).
# Review before running. Run as root: sudo bash scripts/install-ubuntu.sh

APP_DIR="${APP_DIR:-/sql-ledger}"
DB_NAME="${DB_NAME:-ledger}"
DB_USER="${DB_USER:-sql-ledger}"
DB_PASS="${DB_PASS:-change-me-strong-password}"
WWW_USER="${WWW_USER:-www-data}"
REPO_URL="${REPO_URL:-https://github.com/rsuhaendi/sql-ledger-fixmenu.git}"
BRANCH="${BRANCH:-fixmenu}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash scripts/install-ubuntu.sh" >&2
  exit 1
fi

apt-get update
apt-get install -y apache2 postgresql postgresql-contrib \
  perl libdbi-perl libdbd-pg-perl libmail-sendmail-perl \
  texlive-latex-base texlive-latex-extra texlive-fonts-recommended \
  texlive-lang-other texlive-xetex fonts-dejavu git

a2enmod cgi || true

if [[ ! -d "$APP_DIR/.git" ]]; then
  git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
mkdir -p spool templates users
chown -R "$WWW_USER:$WWW_USER" "$APP_DIR"
chmod 711 "$APP_DIR" "$APP_DIR/users" "$APP_DIR/templates" "$APP_DIR/spool"

if [[ ! -f "$APP_DIR/sql-ledger.conf" ]]; then
  cp "$APP_DIR/sql-ledger.conf.default" "$APP_DIR/sql-ledger.conf"
fi

install -m 0644 "$APP_DIR/config/examples/sql-ledger-apache.conf" /etc/apache2/conf-available/sql-ledger.conf
a2enconf sql-ledger || true
systemctl reload apache2

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE ROLE \"$DB_USER\" WITH LOGIN PASSWORD '$DB_PASS';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\" ENCODING 'UTF8' TEMPLATE template0;"

echo
echo "Install done."
echo "Next steps:"
echo "1. Open http://SERVER/sql-ledger/admin.pl and create admin password."
echo "2. Create/login dataset using DB name=$DB_NAME, user=$DB_USER, password you set."
echo "3. Restrict admin.pl at Apache level until password is set."
echo "4. After deploy, remind users to Ctrl+F5."
