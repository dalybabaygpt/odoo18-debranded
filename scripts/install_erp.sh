#!/usr/bin/env bash
# Generic ERP Full Auto-Installer
# Compatible with Ubuntu 22.04 and 24.04
set -e
clear

echo "========================================="
echo "   Generic ERP Full Auto-Installer       "
echo "========================================="

# -- User Inputs --
read -p "Enter ERP project name (example: myerp): " PROJECT_NAME
read -p "Enter domain (leave blank for IP-only): " DOMAIN
read -s -p "Enter admin password for database: " ADMIN_PASSWORD
echo

# -- OS Check --
UBX=$(lsb_release -rs)
if [[ "$UBX" != "22.04" && "$UBX" != "24.04" ]]; then
  echo "❌ Unsupported Ubuntu version: $UBX. Only 22.04 or 24.04 supported."
  exit 1
fi

echo "✅ Ubuntu $UBX detected."

# -- Install Dependencies --
apt update
DEPS=(git wget curl python3-venv python3-pip python3-wheel python3-dev build-essential \
      libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev \
      libjpeg-dev zlib1g-dev libevent-dev libatlas-base-dev postgresql nginx)
for pkg in "${DEPS[@]}"; do apt install -y "$pkg"; done

echo "✅ System dependencies installed."

# -- Install Certbot --
if ! command -v certbot &>/dev/null; then
  echo "🔐 Installing Certbot..."
  if [[ "$UBX" == "24.04" ]]; then
    snap install core && snap refresh core && snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
  else
    apt install -y certbot python3-certbot-nginx
  fi
fi

# -- PostgreSQL Setup --
systemctl enable postgresql && systemctl start postgresql
echo "✅ PostgreSQL started."

# Create role and database
if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$PROJECT_NAME'" | grep -q 1; then
  sudo -u postgres createuser --createdb "$PROJECT_NAME"
  echo "✅ PostgreSQL role '$PROJECT_NAME' created."
else
  echo "ℹ️ PostgreSQL role '$PROJECT_NAME' exists."
fi
if ! sudo -u postgres psql -lqt | cut -d '|' -f1 | grep -qw "$PROJECT_NAME"; then
  sudo -u postgres createdb -O "$PROJECT_NAME" "$PROJECT_NAME"
  echo "✅ Database '$PROJECT_NAME' created."
else
  echo "ℹ️ Database '$PROJECT_NAME' exists."
fi

echo "✅ PostgreSQL role & database ready."

# -- Setup ERP Structure --
ERP_ROOT=/opt/erp/$PROJECT_NAME
mkdir -p "$ERP_ROOT"/server "$ERP_ROOT"/custom_addons "$ERP_ROOT"/venv
useradd -m -d "$ERP_ROOT" -s /bin/bash "$PROJECT_NAME" 2>/dev/null || true
chown -R "$PROJECT_NAME":"$PROJECT_NAME" "$ERP_ROOT"

echo "✅ ERP directory structure created at $ERP_ROOT."

# -- Clone Odoo 18 CE --
if [[ ! -d "$ERP_ROOT/server/.git" ]]; then
  echo "📥 Cloning Odoo 18 CE..."
  sudo -u "$PROJECT_NAME" git clone --depth 1 --branch 18.0 https://github.com/odoo/odoo.git "$ERP_ROOT/server"
fi

echo "✅ Odoo source ready."

# -- Python Virtualenv & Dependencies --
echo "🐍 Setting up Python virtualenv..."
sudo -u "$PROJECT_NAME" python3 -m venv "$ERP_ROOT/venv"
sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/pip" install --upgrade pip wheel
sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/pip" install -r "$ERP_ROOT/server/requirements.txt" || true

echo "✅ Python virtualenv and requirements installed."

# -- ERP Configuration --
echo "⚙️ Creating config file..."
mkdir -p /etc/erp
cat > /etc/erp/$PROJECT_NAME.conf <<EOF
[options]
admin_passwd = $ADMIN_PASSWORD
db_host = False
db_port = False
db_user = $PROJECT_NAME
db_password = False
addons_path = $ERP_ROOT/server/addons,$ERP_ROOT/custom_addons
logfile = /var/log/$PROJECT_NAME/odoo.log
proxy_mode = True
workers = 2
EOF

# -- Log Directory --
echo "🗄️ Setting up log directory..."
mkdir -p /var/log/$PROJECT_NAME
touch /var/log/$PROJECT_NAME/odoo.log
chown -R "$PROJECT_NAME":"$PROJECT_NAME" /var/log/$PROJECT_NAME

echo "✅ Log directory setup."

# -- Initialize Database --
echo "🚀 Initializing database and base module..."
sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/python3" "$ERP_ROOT/server/odoo-bin" \
  -c /etc/erp/$PROJECT_NAME.conf \
  -d "$PROJECT_NAME" \
  -i base \
  --without-demo=all \
  --load-language=en_US \
  --stop-after-init

echo "✅ Database initialized."

# -- Create systemd Service --
echo "🛠️ Creating systemd service..."
cat > /etc/systemd/system/$PROJECT_NAME.service <<EOF
[Unit]
Description=$PROJECT_NAME ERP Service
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=$PROJECT_NAME
Group=$PROJECT_NAME
ExecStart=$ERP_ROOT/venv/bin/python3 $ERP_ROOT/server/odoo-bin -c /etc/erp/$PROJECT_NAME.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable $PROJECT_NAME && systemctl start $PROJECT_NAME

echo "✅ systemd service '$PROJECT_NAME' started."

# -- Nginx Configuration --
echo "🌐 Configuring Nginx..."
# Remove all existing site configs and default conf
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/conf.d/default.conf

if [[ -n "$DOMAIN" ]]; then
  echo "🔗 Domain mode for $DOMAIN..."
  # HTTP -> HTTPS redirect
  cat > /etc/nginx/sites-available/$PROJECT_NAME <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOF
  # Secure site
  cat >> /etc/nginx/sites-available/$PROJECT_NAME <<EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    client_max_body_size 100M;
    proxy_read_timeout 86400;
    proxy_connect_timeout 86400;
    proxy_send_timeout 86400;

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
  ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/$PROJECT_NAME
  nginx -t && systemctl reload nginx

  # Issue SSL if DNS resolves
  if getent hosts "$DOMAIN" > /dev/null; then
    certbot --nginx -d "$DOMAIN" --agree-tos --non-interactive --register-unsafely-without-email || echo "⚠️ SSL issuance failed; proceeding without SSL."
  else
    echo "⚠️ DNS not ready; skipping SSL issuance."
  fi
else
  echo "🔗 IP-only mode..."
  cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
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
  ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
fi

echo "
========================================="
echo " 🎉 Installation Complete for $PROJECT_NAME 🎉"
echo "========================================="
echo " Access your ERP:"
if [[ -n "$DOMAIN" ]]; then
  echo "   https://$DOMAIN"
else
  echo "   http://$(hostname -I | awk '{print $1}'):8069"
fi
