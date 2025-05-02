#!/usr/bin/env bash
# Final Generic ERP Installer with Safe DB Init
# Ubuntu 22.04 / 24.04 compatible with IP access via port 80

set -e
clear

# === Banner ===
echo "========================================="
echo "   Generic ERP Full Auto-Installer       "
echo "        (authbind | port 80 safe init)   "
echo "========================================="

# === Inputs ===
read -p "Enter ERP project name (e.g. myerp): " PROJECT_NAME
read -s -p "Enter admin password for database: " ADMIN_PASSWORD
echo

# === OS Check ===
UBX=$(lsb_release -rs)
if [[ "$UBX" != "22.04" && "$UBX" != "24.04" ]]; then
  echo "❌ Ubuntu $UBX is not supported. Use 22.04 or 24.04."
  exit 1
fi

# === Install Core Packages ===
echo "📦 Installing required packages..."
apt update && apt install -y git wget curl python3-venv python3-pip python3-wheel python3-dev \
  build-essential libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev \
  libjpeg-dev zlib1g-dev libevent-dev libatlas-base-dev postgresql authbind

# === PostgreSQL Setup ===
echo "🗄️ Setting up PostgreSQL..."
systemctl enable postgresql && systemctl start postgresql
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$PROJECT_NAME'" | grep -q 1 || \
  sudo -u postgres createuser --createdb "$PROJECT_NAME"
sudo -u postgres psql -lqt | cut -d '|' -f1 | grep -qw "$PROJECT_NAME" || \
  sudo -u postgres createdb -O "$PROJECT_NAME" "$PROJECT_NAME"

# === ERP Project Structure ===
ERP_ROOT="/opt/erp/$PROJECT_NAME"
mkdir -p "$ERP_ROOT/server" "$ERP_ROOT/custom_addons" "$ERP_ROOT/venv"
useradd -m -d "$ERP_ROOT" -s /bin/bash "$PROJECT_NAME" 2>/dev/null || true
chown -R "$PROJECT_NAME":"$PROJECT_NAME" "$ERP_ROOT"

# === Clone Odoo ===
echo "📥 Cloning Odoo 18.0..."
sudo -u "$PROJECT_NAME" git clone --depth 1 --branch 18.0 https://github.com/odoo/odoo.git "$ERP_ROOT/server"

# === Python venv ===
sudo -u "$PROJECT_NAME" python3 -m venv "$ERP_ROOT/venv"
sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/pip" install --upgrade pip wheel

# Retry requirements install up to 3 times
for i in {1..3}; do
  sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/pip" install -r "$ERP_ROOT/server/requirements.txt" && break || {
    echo "⚠️ Attempt $i to install Python requirements failed. Retrying..."
    sleep 2
  }
done

# === ERP Config ===
echo "⚙️ Writing config file..."
mkdir -p /etc/erp
cat > "/etc/erp/$PROJECT_NAME.conf" <<EOF
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
http_port = 8769
EOF

mkdir -p "/var/log/$PROJECT_NAME"
touch "/var/log/$PROJECT_NAME/odoo.log"
chown -R "$PROJECT_NAME":"$PROJECT_NAME" "/var/log/$PROJECT_NAME"

# === Authbind for port 80 ===
echo "🔓 Preparing authbind for port 80..."
touch /etc/authbind/byport/80
chmod 500 /etc/authbind/byport/80
chown $PROJECT_NAME /etc/authbind/byport/80

# === Run Init On Port 8769 ===
echo "🚀 Initializing ERP database safely (port 8769)..."
sudo -u "$PROJECT_NAME" "$ERP_ROOT/venv/bin/python3" "$ERP_ROOT/server/odoo-bin" \
  -c "/etc/erp/$PROJECT_NAME.conf" -d "$PROJECT_NAME" -i base \
  --without-demo=all --load-language=en_US --stop-after-init || {
  echo "❌ ERP init failed"
  journalctl -xe
  exit 1
}

# === Update config for port 80 ===
sed -i 's/http_port = 8769/http_port = 80/' "/etc/erp/$PROJECT_NAME.conf"

# === systemd service ===
echo "🔁 Creating systemd service..."
cat > "/etc/systemd/system/$PROJECT_NAME.service" <<EOF
[Unit]
Description=$PROJECT_NAME ERP Service
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=$PROJECT_NAME
Group=$PROJECT_NAME
ExecStart=/usr/bin/authbind $ERP_ROOT/venv/bin/python3 $ERP_ROOT/server/odoo-bin -c /etc/erp/$PROJECT_NAME.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$PROJECT_NAME"
systemctl restart "$PROJECT_NAME"

sleep 3

# === Final Curl Check ===
echo "🌐 Verifying HTTP access on port 80..."
if curl -s --head http://127.0.0.1 | grep -i '200 OK' > /dev/null; then
  echo "✅ ERP is accessible on port 80."
else
  echo "❌ ERP failed to respond on port 80. Check logs: journalctl -u $PROJECT_NAME --no-pager"
  exit 1
fi

# === Final Info ===
echo -e "\n========================================="
echo " 🎉 ERP $PROJECT_NAME installed and running 🎉"
echo "========================================="
echo " Access it via: http://$(hostname -I | awk '{print $1}')"
echo " Default login: admin / $ADMIN_PASSWORD"
echo "========================================="
