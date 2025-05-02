#!/bin/bash

# =============================
# SmartERP IP-Only Auto Install
# =============================

# Ask DB name (admin password is hardcoded to: admin)
read -p "Enter database name (example: smarterp): " DB_NAME
read -p "Enter your GitHub username: " GITHUB_USER
read -p "Enter your GitHub token: " GITHUB_TOKEN

# Update + dependencies
apt update && apt upgrade -y
apt install -y git wget curl python3-pip python3-dev python3-venv build-essential \
  libxslt1-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools \
  libjpeg-dev zlib1g-dev libpq-dev libxml2-dev libffi-dev libssl-dev \
  libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev \
  postgresql nginx node-less

# PostgreSQL setup
su - postgres -c "psql -c \"CREATE USER odoo WITH PASSWORD 'odoo';\""

# Directories
mkdir -p /opt/odoo
cd /opt/odoo

# Clone Odoo CE 18
git clone https://github.com/odoo/odoo --depth 1 --branch 18.0
python3 -m venv venv
source venv/bin/activate
pip install wheel
pip install -r odoo/requirements.txt

# Get your custom addons
mkdir -p /opt/odoo/custom-addons
git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/odoo18-debranded.git /opt/odoo/tmp
mv /opt/odoo/tmp/custom_addons/* /opt/odoo/custom-addons/
rm -rf /opt/odoo/tmp

# Odoo config
cat <<EOF > /etc/odoo.conf
[options]
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom-addons
admin_passwd = admin
db_user = odoo
db_password = odoo
db_host = False
db_port = False
dbfilter = ^$DB_NAME\$
logfile = /var/log/odoo/odoo.log
EOF

# Systemd service
cat <<EOF > /etc/systemd/system/smarterp.service
[Unit]
Description=SmartERP
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
systemctl enable smarterp
systemctl start smarterp

# Wait + create database
sleep 10
/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -d $DB_NAME --without-demo=all --init base --admin-password admin

# Install custom modules
/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -d $DB_NAME -i $(ls /opt/odoo/custom-addons | tr '\n' ',' | sed 's/,$//') --stop-after-init

# Final
echo "===================================="
echo "✅ SmartERP Installed via IP Access"
echo "===================================="
echo "URL: http://<YOUR_IP>:8069"
echo "Database: $DB_NAME"
echo "Admin Password: admin"
