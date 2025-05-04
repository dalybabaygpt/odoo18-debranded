#!/usr/bin/env bash

# ===================================================
#   Simple SmartERP Installer: Odoo CE 18 (No DB)
# ===================================================
# This script installs Odoo CE 18 Community Edition and your custom-addons
# It sets up the Python environment, systemd service, and opens port 8069.
# It DOES NOT create any database. You can create DB manually later.

set -euo pipefail

# --- Configuration ---
GITHUB_USER="dalybabaygpt"              # your GitHub username
GITHUB_TOKEN=""                         # your GitHub token (if private repo)
MASTER_PASSWORD="time2fly"              # master password for odoo.conf

# --- Install dependencies ---
apt update && apt upgrade -y
apt install -y git wget curl build-essential python3-dev python3-venv python3-pip \
    libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev \
    libjpeg-dev zlib1g-dev libevent-dev libatlas-base-dev postgresql nginx ufw

# --- PostgreSQL user setup ---
# Create a database role "odoo" if not exists
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE ROLE odoo LOGIN PASSWORD 'odoo' CREATEDB;"

# Adjust auth to md5
sed -i 's/^local\s\+all\s\+all\s\+.*/local   all             all                                     md5/' \
    /etc/postgresql/*/main/pg_hba.conf
sed -i 's/^host\s\+all\s\+all\s\+127.0.0.1\/32\s\+.*/host    all             all             127.0.0.1\/32            md5/' \
    /etc/postgresql/*/main/pg_hba.conf
sed -i 's/^host\s\+all\s\+all\s\+::1\/128\s\+.*/host    all             all             ::1\/128                 md5/' \
    /etc/postgresql/*/main/pg_hba.conf
systemctl restart postgresql

# --- Install Odoo CE 18 ---
mkdir -p /opt/odoo
cd /opt/odoo
git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 odoo
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip wheel
pip install -r odoo/requirements.txt

echo "Cloned and installed Odoo CE 18"

# --- Install custom-addons ---
mkdir -p /opt/odoo/custom-addons
if [[ -n "$GITHUB_TOKEN" ]]; then
    git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/odoo18-debranded.git /opt/odoo/tmp
else
    git clone https://github.com/$GITHUB_USER/odoo18-debranded.git /opt/odoo/tmp
fi
mv /opt/odoo/tmp/custom_addons/* /opt/odoo/custom-addons/
rm -rf /opt/odoo/tmp

echo "Installed custom addons"

# --- Create odoo.conf ---
cat <<EOF > /etc/odoo.conf
[options]
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom-addons
admin_passwd = $MASTER_PASSWORD
db_host = False
db_port = False
db_user = odoo
db_password = odoo
logfile = /var/log/odoo/odoo.log
EOF

# --- Systemd service ---
cat <<EOF > /etc/systemd/system/smarterp.service
[Unit]
Description=SmartERP (Odoo 18)
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
enable smarterp
start smarterp

echo "Odoo service started"

# --- Open firewall ---
ufw allow 8069
echo "Port 8069 opened"

# --- Done ---
echo "================================" 
echo "Odoo CE 18 installed successfully" 
echo "Access: http://<server_ip>:8069" 
echo "Create your databases manually via the web UI" 
echo "================================"
