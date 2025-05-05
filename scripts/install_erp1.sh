#!/usr/bin/env bash

# ===================================================
#   Odoo CE 18 Installer (No Database Creation)
# ===================================================
# Installs Odoo Community 18 and your custom modules (public repo).
# Does NOT create any database—create one manually via the web UI.

set -euo pipefail

# --- User configuration via environment ---
#   You can override these by exporting before running.
GITHUB_USER="${GITHUB_USER:-dalybabay}"
MASTER_PASSWORD="${MASTER_PASSWORD:-time2fly}"

# --- Install system dependencies ---
apt update && apt upgrade -y
apt install -y git wget curl build-essential python3-dev python3-venv python3-pip python3-wheel \
    libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev \
    libjpeg-dev zlib1g-dev libevent-dev libatlas-base-dev postgresql nginx ufw

# --- PostgreSQL role setup ---
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE ROLE odoo LOGIN PASSWORD 'odoo' CREATEDB;"
fi

# Enforce md5 authentication
PG_HBA="/etc/postgresql/$(ls /etc/postgresql)/main/pg_hba.conf"
sed -i "s/^local\s\+all\s\+all\s\+.*/local   all             all                                     md5/" "$PG_HBA"
sed -i "s|^host\s\+all\s\+all\s\+127.0.0.1/32\s\+.*|host    all             all             127.0.0.1/32            md5|" "$PG_HBA"
sed -i "s|^host\s\+all\s\+all\s\+::1/128\s\+.*|host    all             all             ::1/128                 md5|" "$PG_HBA"
systemctl restart postgresql

# --- Odoo CE 18 installation ---
rm -rf /opt/odoo && mkdir -p /opt/odoo
cd /opt/odoo
git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 odoo
python3 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate
pip install --upgrade pip wheel
pip install -r odoo/requirements.txt

echo "✅ Odoo CE 18 core installed"

# --- Custom-addons installation ---
CUSTOM_DIR="/opt/odoo/custom-addons"
rm -rf "$CUSTOM_DIR"
mkdir -p "$CUSTOM_DIR"
TMP_DIR="/opt/odoo/tmp"
rm -rf "$TMP_DIR"
git clone https://github.com/${GITHUB_USER}/odoo18-debranded.git "$TMP_DIR"
if [ -d "$TMP_DIR/custom_addons" ]; then
    mv "$TMP_DIR/custom_addons"/* "$CUSTOM_DIR/"
fi
rm -rf "$TMP_DIR"

echo "✅ Custom-addons installed to $CUSTOM_DIR"

# --- Odoo configuration file ---
cat <<EOF > /etc/odoo.conf
[options]
addons_path = /opt/odoo/odoo/addons,$CUSTOM_DIR
admin_passwd = $MASTER_PASSWORD
db_host = False
db_port = False
db_user = odoo
db_password = odoo
logfile = /var/log/odoo/odoo.log
EOF

# --- systemd service setup ---
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo Open Source ERP (Community Edition)
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

echo "✅ Odoo service started"

# --- firewall ---
ufw allow 8069/tcp

echo "================================"
echo "Odoo CE 18 installed successfully"
echo "Access it at: http://<server_ip>:8069"
echo "Create your database via: http://<server_ip>:8069/web/database/create"
echo "Use Master Password: $MASTER_PASSWORD"
echo "================================"
