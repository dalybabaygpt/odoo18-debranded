#!/bin/bash

set -e  # Exit if any error

clear

echo "========================================="
echo "      Generic ERP Full Auto-Installer    "
echo "========================================="

# Ask user inputs
read -p "Enter your ERP Project Name (example: myerp): " PROJECT_NAME
read -p "Enter domain name (leave empty if no domain yet): " DOMAIN
read -s -p "Enter admin password for database: " ADMIN_PASSWORD

# Ubuntu version detection
UBUNTU_VERSION=$(lsb_release -rs)

if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then
    echo "❌ Unsupported Ubuntu version: $UBUNTU_VERSION. Only 22.04 and 24.04 supported."
    exit 1
fi

echo "\n✅ Ubuntu $UBUNTU_VERSION detected. Proceeding..."

# Install core packages
apt update && apt install -y git wget curl python3-pip python3-venv python3-wheel python3-dev build-essential \
    libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev libjpeg-dev zlib1g-dev libevent-dev \
    libatlas-base-dev postgresql nginx software-properties-common

# Certbot setup
if ! command -v certbot &> /dev/null
then
    if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
        snap install core; snap refresh core; snap install --classic certbot
        ln -s /snap/bin/certbot /usr/bin/certbot
    else
        apt install -y certbot python3-certbot-nginx
    fi
fi

# Setup PostgreSQL
systemctl enable postgresql
systemctl start postgresql

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PROJECT_NAME'" | grep -q 1; then
  sudo -u postgres createuser --createdb "$PROJECT_NAME"
  echo "✅ PostgreSQL user '$PROJECT_NAME' created."
else
  echo "ℹ️ PostgreSQL user '$PROJECT_NAME' already exists."
fi

# Create project structure
mkdir -p /opt/erp/$PROJECT_NAME/{server,custom_addons,venv}
useradd -m -d /opt/erp/$PROJECT_NAME -U -r -s /bin/bash $PROJECT_NAME 2>/dev/null || echo "User already exists"
chown -R $PROJECT_NAME: /opt/erp/$PROJECT_NAME

# Clone Odoo 18 (clean)
if [ ! -d /opt/erp/$PROJECT_NAME/server/.git ]; then
    sudo -u $PROJECT_NAME git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 /opt/erp/$PROJECT_NAME/server
fi

# Setup virtualenv
sudo -u $PROJECT_NAME python3 -m venv /opt/erp/$PROJECT_NAME/venv
source /opt/erp/$PROJECT_NAME/venv/bin/activate
pip install --upgrade pip wheel
pip install -r /opt/erp/$PROJECT_NAME/server/requirements.txt || true

# Create configuration
mkdir -p /etc/erp
cat <<EOF > /etc/erp/$PROJECT_NAME.conf
[options]
admin_passwd = $ADMIN_PASSWORD
db_host = False
db_port = False
db_user = $PROJECT_NAME
db_password = False
addons_path = /opt/erp/$PROJECT_NAME/server/addons,/opt/erp/$PROJECT_NAME/custom_addons
logfile = /var/log/$PROJECT_NAME.log
proxy_mode = True
gevent_port = 8072
workers = 2
EOF

# Create systemd service
cat <<EOF > /etc/systemd/system/$PROJECT_NAME.service
[Unit]
Description=$PROJECT_NAME ERP Server
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=$PROJECT_NAME
PermissionsStartOnly=true
User=$PROJECT_NAME
Group=$PROJECT_NAME
ExecStart=/opt/erp/$PROJECT_NAME/venv/bin/python3 /opt/erp/$PROJECT_NAME/server/odoo-bin -c /etc/erp/$PROJECT_NAME.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $PROJECT_NAME
systemctl restart $PROJECT_NAME

# Wait ERP startup
sleep 10

# Create default database
/opt/erp/$PROJECT_NAME/venv/bin/python3 /opt/erp/$PROJECT_NAME/server/odoo-bin -d $PROJECT_NAME -i base --without-demo=all --load-language=en_US --admin-password=$ADMIN_PASSWORD --stop-after-init

# Setup Nginx
if [ -n "$DOMAIN" ]; then
    echo "⚡ Setting up Nginx for domain $DOMAIN"
    cat <<EOF > /etc/nginx/sites-available/$PROJECT_NAME
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

    access_log /var/log/nginx/$PROJECT_NAME.access.log;
    error_log /var/log/nginx/$PROJECT_NAME.error.log;

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_redirect off;
    }
    location /longpolling/ {
        proxy_pass http://127.0.0.1:8072;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default || true
    systemctl reload nginx

    # Validate domain reachable
    if ping -c 1 $DOMAIN &> /dev/null; then
        certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email || echo "⚠️ SSL generation failed. Continuing without SSL."
    else
        echo "⚠️ Domain DNS not ready. Skipping SSL."
    fi

else
    echo "ℹ️ No domain entered. Skipping Nginx setup."
fi

clear

echo "========================================="
echo "🎉 Installation completed successfully!"
echo "========================================="
echo "- Access: http://your-server-ip:8069 or https://$DOMAIN if SSL configured"
echo "- Default login: admin / (your password)"
echo "========================================="
