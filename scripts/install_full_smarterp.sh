#!/bin/bash

# ==============================
#  Odoo CE 18 + Custom Addons
#  IP-Only Installation Script
# ==============================

# Ask for DB name
read -p "Enter database name (lowercase, no spaces): " DB_NAME

# Constants
ADMIN_PASSWORD="admin"
GITHUB_USER="dalybabaygpt"
GITHUB_TOKEN="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"

# Update and install dependencies
apt update && apt upgrade -y
apt install -y git wget curl software-properties-common build-essential \
    python3-dev python3-pip python3-venv python3-wheel python3-setuptools \
    libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev \
    libjpeg-dev zlib1g-dev libevent-dev libatlas-base-dev postgresql \
    python3-psycopg2

# Setup PostgreSQL
su - postgres -c "psql -c \"CREATE USER odoo WITH PASSWORD 'odoo';\""

# Create directories
mkdir -p /opt/odoo
cd /opt/odoo

# Clone Odoo CE 18
git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0

# Create virtualenv
python3 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate

# Install Python packages
pip install wheel
pip install -r odoo/requirements.txt

# Custom addons
mkdir -p /opt/odoo/custom-addons
git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/odoo18-debranded.git /opt/odoo/tmp
mv /opt/odoo/tmp/custom_addons/* /opt/odoo/custom-addons/
rm -rf /opt/odoo/tmp

# Create config file
cat <<EOF > /etc/odoo.conf
[options]
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom-addons
admin_passwd = $ADMIN_PASSWORD
db_host = False
db_port = False
db_user = odoo
db_password = odoo
dbfilter = ^$DB_NAME\$
logfile = /var/log/odoo/odoo.log
EOF

# Create systemd service
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=root
Group=root
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

# Wait for startup
sleep 20

# Create DB and install base
/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin \
    -d $DB_NAME --without-demo=all --init base --admin-password $ADMIN_PASSWORD

# Done
clear
echo "============================="
echo " Odoo 18 Installation DONE "
echo "============================="
echo "Access it on: http://your-server-ip:8069"
echo "Login: admin"
echo "Password: admin"
echo "Database: $DB_NAME"
echo "============================="
