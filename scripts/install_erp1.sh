#!/bin/bash

# ===================================================
# Final Bulletproof SmartERP Install for Odoo CE 18
# Auto-creates DB + pulls custom addons + admin access
# Works on Ubuntu 22.04 and 24.04 — All fixes included
# ===================================================

read -p "Enter database name (example: smarterp): " DB_NAME
read -p "Enter your GitHub username (for custom_addons clone): " GITHUB_USER
read -p "Enter your GitHub token (for private repo access): " GITHUB_TOKEN

ADMIN_PASSWORD="time2fly"
ODOO_LOGIN="admin"
ODOO_PASSWORD="admin"

clear
echo "======================="
echo "SmartERP Install Summary"
echo "======================="
echo "Database: $DB_NAME"
echo "Admin: $ODOO_LOGIN"
echo "Password: $ODOO_PASSWORD"
echo "======================="
sleep 2

# Update system and install packages
apt update && apt upgrade -y
apt install -y git wget curl build-essential python3-dev python3-pip python3-venv \
    python3-wheel python3-setuptools libpq-dev libxml2-dev libxslt1-dev \
    libldap2-dev libsasl2-dev libffi-dev libjpeg-dev zlib1g-dev libevent-dev \
    libatlas-base-dev postgresql nginx ufw

# PostgreSQL user setup
su - postgres -c "psql -c \"CREATE USER odoo WITH PASSWORD 'odoo';\""
sed -i 's/^local\s\+all\s\+all\s\+.*/local   all             all                                     md5/' /etc/postgresql/*/main/pg_hba.conf
sed -i 's/^host\s\+all\s\+all\s\+127.0.0.1\/32\s\+.*/host    all             all             127.0.0.1\/32            md5/' /etc/postgresql/*/main/pg_hba.conf
sed -i 's/^host\s\+all\s\+all\s\+::1\/128\s\+.*/host    all             all             ::1\/128                 md5/' /etc/postgresql/*/main/pg_hba.conf
systemctl restart postgresql

# Setup Odoo
mkdir -p /opt/odoo
cd /opt/odoo
git clone https://github.com/odoo/odoo --depth 1 --branch 18.0
python3 -m venv venv
source venv/bin/activate
pip install wheel
pip install -r odoo/requirements.txt

# Custom addons
mkdir -p /opt/odoo/custom-addons
git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/odoo18-debranded.git /opt/odoo/tmp
mv /opt/odoo/tmp/custom_addons/* /opt/odoo/custom-addons/
rm -rf /opt/odoo/tmp

# Config
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

# Service
cat <<EOF > /etc/systemd/system/smarterp.service
[Unit]
Description=SmartERP
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

systemctl daemon-reload
systemctl enable smarterp
systemctl start smarterp

# Wait for boot
sleep 15

# Create DB
/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -d $DB_NAME --without-demo=all --init base --admin-password $ADMIN_PASSWORD

# Insert admin credentials
PGPASSWORD=odoo psql -U odoo -d $DB_NAME -h 127.0.0.1 <<EOF
UPDATE res_users SET login='$ODOO_LOGIN', password='admin' WHERE id=1;
EOF

# Install modules
/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -d $DB_NAME -i \
  $(ls /opt/odoo/custom-addons | tr '\n' ',' | sed 's/,\$//') --stop-after-init

# Enable port & firewall
ufw allow 8069
ufw --force enable

clear
echo "==============================="
echo "🎉 SmartERP Installation DONE 🎉"
echo "==============================="
echo "Access: http://your_server_ip:8069"
echo "Login: $ODOO_LOGIN"
echo "Password: $ODOO_PASSWORD"
echo "DB Name: $DB_NAME"
echo "==============================="
