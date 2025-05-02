#!/bin/bash

set -e  # Exit immediately if any command fails

echo "📦 Installing SmartERP..."
START_TIME=$(date +%s)

# Check Ubuntu Version
VERSION_ID=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)
if [[ "$VERSION_ID" != "20.04" && "$VERSION_ID" != "22.04" && "$VERSION_ID" != "24.04" ]]; then
  echo "❌ Unsupported Ubuntu version: $VERSION_ID"
  echo "SmartERP installer only supports Ubuntu 20.04, 22.04, or 24.04."
  exit 1
fi

echo "✅ Ubuntu version $VERSION_ID detected."

# Update server and install necessary packages
echo "📦 Installing required system packages..."
apt update
apt install -y git python3-pip python3-venv build-essential wget curl libpq-dev libxml2-dev libxslt1-dev \
libldap2-dev libsasl2-dev libjpeg-dev zlib1g-dev libevent-dev libffi-dev libssl-dev libblas-dev libatlas-base-dev \
postgresql nginx curl software-properties-common

# Ensure PostgreSQL is running
systemctl enable postgresql
systemctl start postgresql

# Create PostgreSQL user for Odoo if not exists
echo "⚙️ Creating PostgreSQL role 'odoo' if not exists..."
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
  sudo -u postgres createuser --createdb odoo
  echo "✅ PostgreSQL user 'odoo' created."
else
  echo "ℹ️ PostgreSQL user 'odoo' already exists. Continuing..."
fi

# Create Odoo user and necessary folders
echo "⚙️ Setting up Odoo folders and user..."
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo 2>/dev/null || echo "User already exists"
mkdir -p /opt/odoo/{odoo,custom_addons,venv} /etc/odoo
chown -R odoo: /opt/odoo

# Clone Odoo 18 CE if not already
if [ ! -d /opt/odoo/odoo/.git ]; then
  echo "📥 Cloning Odoo 18 CE..."
  sudo -u odoo git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 --single-branch /opt/odoo/odoo
fi

# Setup virtualenv
if [ ! -d /opt/odoo/venv/bin ]; then
  echo "⚙️ Creating Python virtual environment..."
  python3 -m venv /opt/odoo/venv
fi

source /opt/odoo/venv/bin/activate

# Upgrade pip and install requirements
echo "📦 Installing Python dependencies..."
pip install --upgrade pip wheel
pip install -r /opt/odoo/odoo/requirements.txt || true
pip install xlwt rjsmin pytz python-stdnum pyserial PyPDF2 polib passlib docopt asn1crypto XlsxWriter xlrd \
urllib3 typing-extensions soupsieve six pyusb pycparser pyasn1 psutil platformdirs Pillow num2words \
maxminddb MarkupSafe lxml isodate idna et-xmlfile docutils decorator chardet certifi cbor2 Babel attrs \
requests reportlab python-dateutil pyasn1_modules openpyxl libsass Jinja2 cffi beautifulsoup4 vobject \
requests-toolbelt requests-file python-ldap ofxparse geoip2 freezegun cryptography zeep pyopenssl

# Create default config if missing
if [ ! -f /etc/odoo/odoo.conf ]; then
  echo "⚙️ Creating Odoo configuration file..."
  cat <<EOF > /etc/odoo/odoo.conf
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom_addons
proxy_mode = True
gevent_port = 8072
workers = 2
max_cron_threads = 1
logfile = /var/log/odoo.log
EOF
fi

# Create systemd service if not exists
if [ ! -f /etc/systemd/system/smarterp.service ]; then
  echo "⚙️ Creating smarterp systemd service..."
  cat <<EOF > /etc/systemd/system/smarterp.service
[Unit]
Description=SmartERP Odoo 18
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=smarterp
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reexec
  systemctl daemon-reload
fi

# Start SmartERP service
echo "🚀 Starting SmartERP service..."
systemctl enable smarterp
systemctl restart smarterp

# Auto-create database 'smarterp' if not exists
echo "⚙️ Creating default database 'smarterp' if not exists..."
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='smarterp'")
if [ "$DB_EXISTS" != "1" ]; then
  source /opt/odoo/venv/bin/activate
  /opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -d smarterp -i base --without-demo=all --load-language=en_US --admin-password=admin
  echo "✅ Database 'smarterp' created successfully!"
else
  echo "ℹ️ Database 'smarterp' already exists. Skipping creation."
fi

END_TIME=$(date +%s)
INSTALLATION_TIME=$((END_TIME - START_TIME))

echo "✅ SmartERP installation completed in $INSTALLATION_TIME seconds!"
echo "========================================"
echo "Access your ERP:"
echo "👉 http://<your-server-ip>:8069"
echo "👉 https://<your-domain> (if SSL configured)"
echo "Username: admin"
echo "Password: admin"
echo "========================================"
