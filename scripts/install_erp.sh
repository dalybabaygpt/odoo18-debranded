#!/usr/bin/env bash
# Generic ERP Full Auto-Installer
# Compatible with Ubuntu 22.04 and 24.04
set -e

# Banner
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
apt install -y git wget curl python3-venv python3-pip python3-wheel python3-dev build-essential \
  libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev \
  libjpeg-dev zlib1g-dev libevent-dev libatlas-base-dev postgresql

echo "✅ System dependencies installed."

# -- PostgreSQL Setup --
echo "🔧 Configuring PostgreSQL..."
systemctl enable postgresql && systemctl start postgresql

if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$PROJECT_NAME'" | grep -q 1; then
  sudo -u postgres createuser --createdb "$PROJECT_NAME"
  echo "✅ Created PostgreSQL role '$PROJECT_NAME'."
else
  echo "ℹ️ PostgreSQL role '$PROJECT_NAME' exists."
fi

if ! sudo -u postgres psql -lqt | cut -d '|' -f1 | grep -qw "$PROJECT_NAME"; then
  sudo -u postgres createdb -O "$PROJECT_NAME" "$PROJECT_NAME"
  echo "✅ Created database '$PROJECT_NAME'."
else
  echo "ℹ️ Database '$PROJECT_NAME' exists."
fi

# -- Directory & User Setup --
ERP_ROOT="/opt/erp/$PROJECT_NAME"
mkdir -p "$ERP_ROOT/server" "$ERP_ROOT/custom_addons" "$ERP_ROOT/venv"
useradd -m -d "$ERP_ROOT" -s /bin/bash "$PROJECT_NAME" 2>/dev/null || true
chown -R "$PROJECT_NAME":"$PROJECT_NAME" "$ERP_ROOT"

# -- Clone Odoo 18 --
if [[ ! -d "$ERP_ROOT/server/.git" ]]; then
  sudo -u "$PROJECT_NAME" git clone --depth 1 --branch 18.0 https://github.com/odoo/odoo.git "$ERP_ROOT/server"
fi

# -- Python venv & Requirements --
sudo -u "$PROJECT_NAME" python3 -m venv "$ERP_ROOT/venv"
sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/pip" install --upgrade pip wheel
sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/pip" install -r "$ERP_ROOT/server/requirements.txt" || true

# -- ERP Config & Logs --
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

mkdir -p /var/log/$PROJECT_NAME
chown -R "$PROJECT_NAME":"$PROJECT_NAME" /var/log/$PROJECT_NAME
touch /var/log/$PROJECT_NAME/odoo.log

# -- Initialize Database --
sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/python3" "$ERP_ROOT/server/odoo-bin" \
  -c /etc/erp/$PROJECT_NAME.conf -d "$PROJECT_NAME" -i base \
  --without-demo=all --load-language=en_US --stop-after-init

# -- systemd Service --
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
systemctl daemon-reload
systemctl enable $PROJECT_NAME
systemctl start $PROJECT_NAME

# -- IP-only mode: remove nginx and forward port 80 to 8069 --
echo "🌐 IP-only mode: removing nginx and forwarding port 80 → 8069"
apt purge -y nginx nginx-common nginx-full || true
rm -rf /etc/nginx
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8069
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 8069

# -- Done --
echo -e "\n========================================="
echo " 🎉 Installation Complete for $PROJECT_NAME 🎉"
echo "========================================="
echo "Access your ERP:"
echo "  http://$(hostname -I | awk '{print $1}'):80"
echo "Default login: admin / $ADMIN_PASSWORD"
