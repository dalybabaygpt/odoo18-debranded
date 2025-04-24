#!/bin/bash

set -e

echo "🔧 Updating and installing dependencies..."
apt update && apt upgrade -y
apt install -y git python3-pip build-essential wget python3-dev python3-venv \
               python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev \
               python3-setuptools node-less libjpeg-dev libpq-dev libffi-dev \
               libxml2-dev libssl-dev libjpeg-dev libblas-dev libatlas-base-dev \
               postgresql nginx curl

echo "👤 Creating Odoo user..."
adduser --system --home=/opt/odoo --group odoo || true
mkdir -p /opt/odoo/custom_addons
chown -R odoo: /opt/odoo

echo "📦 Cloning Odoo CE 18..."
sudo -u odoo git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 --single-branch /opt/odoo/odoo

echo "🐍 Creating Python virtual environment..."
python3 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate
pip install -r /opt/odoo/odoo/requirements.txt

echo "🧠 Configuring PostgreSQL..."
sudo -u postgres createuser -s odoo || true

echo "📁 Moving your SmartERP files..."
cp -r ./etc/odoo.conf /etc/odoo/odoo.conf
cp -r ./custom_addons/* /opt/odoo/custom_addons/
chown -R odoo: /opt/odoo/custom_addons
mkdir -p /var/log/odoo && chown odoo: /var/log/odoo

echo "🛠️ Creating Odoo systemd service..."
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo SmartERP
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Starting Odoo..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

echo "✅ Odoo SmartERP installed successfully!"
echo "Visit: http://<your-server-ip>:8069"
