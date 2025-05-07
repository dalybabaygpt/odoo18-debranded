#!/bin/bash

echo "========== Updating system =========="
apt update && apt upgrade -y

echo "========== Installing required packages =========="
apt install -y git wget curl build-essential libxslt1-dev libzip-dev libldap2-dev libsasl2-dev python3.12 python3.12-venv python3.12-dev libjpeg-dev libpq-dev libxml2-dev libffi-dev libtiff-dev libopenjp2-7-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev libharfbuzz-dev libfribidi-dev libxcb1-dev libx11-dev libxext-dev xfonts-75dpi xfonts-base libxrender1 libxext6 libx11-6 gdebi-core node-less npm

echo "========== Installing PostgreSQL =========="
apt install -y postgresql
sudo -u postgres createuser -s odoo18

echo "========== Creating odoo user and directories =========="
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo
mkdir -p /opt/odoo/odoo-custom-addons
mkdir -p /opt/odoo/venv

echo "========== Installing wkhtmltopdf (Jammy-compatible) =========="
cd /tmp
wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.jammy_amd64.deb
gdebi -n wkhtmltox_0.12.6-1.jammy_amd64.deb
ln -s /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf
ln -s /usr/local/bin/wkhtmltoimage /usr/bin/wkhtmltoimage

echo "========== Cloning Odoo 18 source =========="
cd /opt/odoo
git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 odoo-source
chown -R odoo:odoo /opt/odoo/*

echo "========== Setting up Python 3.12 venv =========="
python3.12 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate
pip install wheel
pip install -r /opt/odoo/odoo-source/requirements.txt

echo "========== Pulling custom addons =========="
cd /opt/odoo
git clone https://github.com/dalybabaygpt/odoo18-debranded.git
cp -r odoo18-debranded/custom_addons/* /opt/odoo/odoo-custom-addons/

echo "========== Creating odoo.conf =========="
cat <<EOF > /etc/odoo.conf
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo18
db_password = False
addons_path = /opt/odoo/odoo-source/addons,/opt/odoo/odoo-custom-addons
logfile = /var/log/odoo/odoo.log
data_dir = /opt/odoo/.local/share/Odoo
EOF

mkdir -p /var/log/odoo
chown -R odoo:odoo /var/log/odoo

echo "========== Creating systemd service =========="
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo-source/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

echo "========== Enabling and starting Odoo service =========="
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

echo "✅ DONE: Access your Odoo at http://YOUR_SERVER_IP:8069"
