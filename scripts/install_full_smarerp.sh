#!/bin/bash

# ===================================================
#  SmartERP Full Automatic Install with Domain + SSL
# ===================================================

# Ask all parameters at the beginning
read -p "Enter domain name (example.com): " DOMAIN
read -p "Enter admin password for database: " ADMIN_PASSWORD
read -p "Enter database name (no spaces, only lowercase, example: smarterp): " DB_NAME
read -p "Enter your VPS email (for SSL certificate alerts, example: you@example.com): " EMAIL
read -p "Enter your GitHub username (for custom_addons clone): " GITHUB_USER
read -p "Enter your GitHub token (for private repo access): " GITHUB_TOKEN

# Summary
clear
echo "======================="
echo "SmartERP Install Summary"
echo "======================="
echo "Domain: $DOMAIN"
echo "Database Name: $DB_NAME"
echo "Admin Password: (hidden)"
echo "SSL Email: $EMAIL"
echo "GitHub User: $GITHUB_USER"
echo "======================="

sleep 2

# Update server and install requirements
apt update && apt upgrade -y
apt install -y git wget curl software-properties-common build-essential python3-dev python3-pip python3-venv python3-wheel python3-setuptools libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev libjpeg-dev zlib1g-dev libevent-dev libatlas-base-dev postgresql nginx certbot python3-certbot-nginx

# Install PostgreSQL and create user
su - postgres -c "psql -c \"CREATE USER odoo WITH PASSWORD 'odoo';\""

# Setup folders
mkdir -p /opt/odoo
cd /opt/odoo

# Clone Odoo CE 18
git clone https://github.com/odoo/odoo --depth 1 --branch 18.0

# Create Python virtualenv
python3 -m venv venv
source venv/bin/activate

# Install Python requirements
pip install wheel
pip install -r odoo/requirements.txt

# Setup custom-addons
mkdir -p /opt/odoo/custom-addons

# Clone your private repo and move custom_addons
git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/odoo18-debranded.git /opt/odoo/tmp
mv /opt/odoo/tmp/custom_addons/* /opt/odoo/custom-addons/
rm -rf /opt/odoo/tmp

# Setup Odoo Configuration
cat <<EOF > /etc/odoo.conf
[options]
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom-addons
admin_passwd = $ADMIN_PASSWORD
db_host = False
db_port = False
db_user = odoo
db_password = odoo
dbfilter = .*
logfile = /var/log/odoo/odoo.log
EOF

# Create Odoo systemd service
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

# Start service
systemctl daemon-reload
systemctl enable smarterp
systemctl start smarterp

# Wait for Odoo to be available
sleep 15

# Create database
/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -d $DB_NAME --db-filter=^$DB_NAME\$ --without-demo=all --init base --admin-password $ADMIN_PASSWORD

# Install all modules automatically
/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -d $DB_NAME --load-language=en_US --log-level=info -i $(ls /opt/odoo/custom-addons | tr '\n' ',' | sed 's/,$//') --stop-after-init

# Setup Nginx
cat <<EOF > /etc/nginx/sites-available/odoo
server {
    listen 80;
    server_name $DOMAIN;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_redirect off;
    }
    location /longpolling/ {
        proxy_pass http://127.0.0.1:8072;
    }
}
EOF

ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
systemctl reload nginx

# Setup SSL with Certbot
certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --redirect --non-interactive

# Finish
clear
echo "==============================="
echo "🎉 SmartERP Installation DONE 🎉"
echo "==============================="
echo "URL: https://$DOMAIN"
echo "Database: $DB_NAME"
echo "Admin Password: $ADMIN_PASSWORD"
echo "==============================="
