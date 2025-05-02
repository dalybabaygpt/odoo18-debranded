#!/bin/bash

set -e
clear

echo "========================================="
echo "   Generic ERP Full Auto-Installer       "
echo "========================================="

# ---- User Inputs ----
read -p "Enter ERP project name (example: myerp): " PROJECT_NAME
read -p "Enter domain name (leave empty if no domain): " DOMAIN
read -s -p "Enter admin password for database: " ADMIN_PASSWORD
echo

# ---- Check Ubuntu Version ----
UBX=$(lsb_release -rs)
if [[ "$UBX" != "22.04" && "$UBX" != "24.04" ]]; then
  echo "❌ Unsupported Ubuntu version: $UBX. Only 22.04 and 24.04 supported."
  exit 1
fi

echo "✅ Ubuntu $UBX detected."

# ---- Install Dependencies ----
apt update
apt install -y git wget curl python3-venv python3-pip python3-wheel python3-dev build-essential \
  libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev libjpeg-dev zlib1g-dev \
  libevent-dev libatlas-base-dev postgresql nginx software-properties-common

# ---- Install Certbot ----
if ! command -v certbot &>/dev/null; then
  if [[ "$UBX" == "24.04" ]]; then
    snap install core; snap refresh core; snap install --classic certbot
    ln -s /snap/bin/certbot /usr/bin/certbot
  else
    apt install -y certbot python3-certbot-nginx
  fi
fi

# ---- PostgreSQL Setup ----
systemctl enable postgresql
systemctl start postgresql

# Create DB user
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PROJECT_NAME'" | grep -q 1; then
  sudo -u postgres createuser --createdb "$PROJECT_NAME"
  echo "✅ PostgreSQL user '$PROJECT_NAME' created."
else
  echo "ℹ️ PostgreSQL user '$PROJECT_NAME' exists."
fi

# Create database
if ! sudo -u postgres psql -lqt | cut -d '|' -f1 | grep -qw "$PROJECT_NAME"; then
  sudo -u postgres createdb -O "$PROJECT_NAME" "$PROJECT_NAME"
  echo "✅ Database '$PROJECT_NAME' created."
else
  echo "ℹ️ Database '$PROJECT_NAME' exists. Skipping creation."
fi

# ---- Setup ERP Directory & User ----
mkdir -p /opt/erp/$PROJECT_NAME/{server,custom_addons,venv}
useradd -m -d /opt/erp/$PROJECT_NAME -U -r -s /bin/bash $PROJECT_NAME 2>/dev/null || true
chown -R $PROJECT_NAME: /opt/erp/$PROJECT_NAME

# ---- Clone ERP Server Code ----
if [ ! -d /opt/erp/$PROJECT_NAME/server/.git ]; then
  sudo -u $PROJECT_NAME git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 /opt/erp/$PROJECT_NAME/server
fi

# ---- Python Virtualenv & Dependencies ----
sudo -u $PROJECT_NAME python3 -m venv /opt/erp/$PROJECT_NAME/venv
source /opt/erp/$PROJECT_NAME/venv/bin/activate
pip install --upgrade pip wheel
pip install -r /opt/erp/$PROJECT_NAME/server/requirements.txt || true

# ---- ERP Configuration ----
mkdir -p /etc/erp
cat > /etc/erp/$PROJECT_NAME.conf <<EOF
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

# ---- Systemd Service ----
cat > /etc/systemd/system/$PROJECT_NAME.service <<EOF
[Unit]
Description=$PROJECT_NAME ERP Server
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
User=$PROJECT_NAME
Group=$PROJECT_NAME
ExecStart=/opt/erp/$PROJECT_NAME/venv/bin/python3 /opt/erp/$PROJECT_NAME/server/odoo-bin -c /etc/erp/$PROJECT_NAME.conf
SyslogIdentifier=$PROJECT_NAME
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $PROJECT_NAME
systemctl restart $PROJECT_NAME

# ---- Initialize Base Module ----
echo "🚀 Initializing ERP database modules..."
source /opt/erp/$PROJECT_NAME/venv/bin/activate
/opt/erp/$PROJECT_NAME/venv/bin/python3 /opt/erp/$PROJECT_NAME/server/odoo-bin \
  -c /etc/erp/$PROJECT_NAME.conf \
  -d $PROJECT_NAME \
  -i base \
  --without-demo=all \
  --load-language=en_US \
  --stop-after-init

# ---- Nginx & SSL ----
if [[ -n "$DOMAIN" ]]; then
  echo "🌐 Configuring Nginx for $DOMAIN..."
  cat > /etc/nginx/sites-available/$PROJECT_NAME <<EOF
map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''      close;
}

server {
  listen 80;
  server_name $DOMAIN;
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name $DOMAIN;

  client_max_body_size 100M;
  proxy_read_timeout 86400s;
  proxy_connect_timeout 86400s;
  proxy_send_timeout 86400s;
  proxy_buffering off;

  ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  location / {
    proxy_pass http://127.0.0.1:8069;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
  }
  location /longpolling {
    proxy_pass http://127.0.0.1:8072;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
  }
}
EOF
  ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx

  if ping -c1 "$DOMAIN" &>/dev/null; then
    certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email || echo "⚠️ SSL issuance failed; continuing without SSL."
  else
    echo "⚠️ DNS not ready; skipping SSL issuance."
  fi
fi

# ---- Finish ----
clear
echo "========================================="
echo "🎉 $PROJECT_NAME installation complete! 🎉"
echo "========================================="
echo "Access URLs:"
echo "  HTTP:  http://<SERVER_IP>:8069"
[[ -n "$DOMAIN" ]] && echo "  HTTPS: https://$DOMAIN"
echo "Default credentials: admin / $ADMIN_PASSWORD"
echo "========================================="
