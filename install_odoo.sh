#!/bin/bash

echo "📦 Installing SmartERP..."

# Ensure required packages are installed
apt update && apt install -y git python3-pip python3-venv libpq-dev libxml2-dev libxslt1-dev \
  libldap2-dev libsasl2-dev libjpeg-dev zlib1g-dev libevent-dev libffi-dev \
  libssl-dev libblas-dev libatlas-base-dev postgresql nginx curl software-properties-common

# Create Odoo user and folders
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo 2>/dev/null || echo "User already exists"
mkdir -p /opt/odoo/{odoo,custom_addons,venv} /etc/odoo
chown -R odoo: /opt/odoo

# Clone Odoo CE 18 if not exists
if [ ! -d /opt/odoo/odoo/.git ]; then
  sudo -u odoo git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 --single-branch /opt/odoo/odoo
fi

# Setup virtualenv
if [ ! -d /opt/odoo/venv/bin ]; then
  python3 -m venv /opt/odoo/venv
fi
source /opt/odoo/venv/bin/activate

# Upgrade pip and install requirements
pip install --upgrade pip
pip install -r /opt/odoo/odoo/requirements.txt || true
pip install wheel
pip install xlwt rjsmin pytz python-stdnum pyserial PyPDF2 polib passlib docopt asn1crypto XlsxWriter xlrd \
  urllib3 typing-extensions soupsieve six pyusb pycparser pyasn1 psutil platformdirs Pillow num2words \
  maxminddb MarkupSafe lxml isodate idna et-xmlfile docutils decorator chardet certifi cbor2 Babel attrs \
  requests reportlab python-dateutil pyasn1_modules openpyxl libsass Jinja2 cffi beautifulsoup4 vobject \
  requests-toolbelt requests-file python-ldap ofxparse geoip2 freezegun cryptography zeep pyopenssl

# Create default config if missing
if [ ! -f /etc/odoo/odoo.conf ]; then
  cat <<EOF > /etc/odoo/odoo.conf
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom_addons
proxy_mode = True
logfile = /var/log/odoo.log
EOF
fi

# Create systemd service if not exists
if [ ! -f /etc/systemd/system/odoo.service ]; then
  cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo SmartERP
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
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

# Start Odoo
systemctl enable odoo
systemctl restart odoo

# Ask for domain configuration
read -p "🌐 Do you want to configure a domain with nginx and SSL? (y/n): " CONFIGURE_DOMAIN
if [[ "$CONFIGURE_DOMAIN" == "y" ]]; then
  read -p "📝 Enter your domain name (e.g. erp.example.com): " DOMAIN

  # Create nginx config
  cat <<EOF > /etc/nginx/sites-available/odoo
upstream odoo {
    server 127.0.0.1:8069;
}
upstream odoochat {
    server 127.0.0.1:8072;
}
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

    location /longpolling {
        proxy_pass http://odoochat;
    }

    location / {
        proxy_redirect off;
        proxy_pass http://odoo;
    }

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

  ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
  nginx -t && systemctl reload nginx

  # SSL
  apt install -y certbot python3-certbot-nginx
  certbot --nginx -d "$DOMAIN"
fi

echo "✅ Odoo SmartERP is ready!"
echo "Visit: http://<your-ip>:8069 or https://$DOMAIN (if configured)"
