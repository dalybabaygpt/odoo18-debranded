#!/bin/bash

echo "========== Updating System =========="
apt update && apt upgrade -y

echo "========== Installing Dependencies =========="
apt install -y git wget curl python3-pip build-essential \
  libxslt1-dev libzip-dev libldap2-dev libsasl2-dev python3-dev \
  libjpeg-dev libpq-dev libxml2-dev libssl-dev libffi-dev \
  zlib1g-dev libtiff-dev libopenjp2-7-dev libwebp-dev \
  libharfbuzz-dev libfribidi-dev libxcb1-dev liblcms2-dev \
  node-less npm libjpeg8-dev libpq-dev libxml2-dev libxslt1-dev \
  python3-venv libjpeg-dev gdebi libpq-dev postgresql postgresql-client

echo "========== Creating Odoo User and Directory =========="
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo18
mkdir -p /opt/odoo
chown odoo18:odoo18 /opt/odoo

echo "========== Installing Wkhtmltopdf =========="
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.jammy_amd64.deb
apt install -y ./wkhtmltox_0.12.6-1.jammy_amd64.deb
rm wkhtmltox_0.12.6-1.jammy_amd64.deb

echo "========== Cloning Odoo 18 CE =========="
cd /opt/odoo
sudo -u odoo18 git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 odoo-source

echo "========== Creating Python Virtual Environment =========="
sudo -u odoo18 python3 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate
pip install wheel
pip install -r /opt/odoo/odoo-source/requirements.txt
deactivate

echo "========== PostgreSQL Setup =========="
sudo -u postgres createuser -s odoo18 || true

read -sp "🔐 Enter the PostgreSQL master password to use with Odoo: " pg_pass
echo
sudo -u postgres psql -c "ALTER USER odoo18 WITH PASSWORD '$pg_pass';"

# Update pg_hba.conf if necessary
PG_HBA_FILE=$(sudo -u postgres psql -t -P format=unaligned -c "SHOW hba_file;")
if ! grep -q "local\s\+all\s\+odoo18\s\+md5" "$PG_HBA_FILE"; then
    echo "local   all             odoo18                                  md5" >> "$PG_HBA_FILE"
    systemctl restart postgresql
fi

echo "========== Creating Configuration File =========="
cat <<EOF > /etc/odoo.conf
[options]
admin_passwd = $pg_pass
db_host = False
db_port = False
db_user = odoo18
db_password = $pg_pass
addons_path = /opt/odoo/odoo-source/addons,/opt/odoo/custom
logfile = /var/log/odoo18.log
EOF

echo "========== Creating Custom Addons Directory =========="
mkdir -p /opt/odoo/custom
chown -R odoo18:odoo18 /opt/odoo

echo "========== Creating Systemd Service =========="
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo18
Group=odoo18
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo-source/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

echo "========== Starting Odoo =========="
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now odoo

echo "========== Odoo Installed Successfully! =========="
echo "Access it at: http://YOUR_SERVER_IP:8069"
