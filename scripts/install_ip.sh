#!/bin/bash

# Exit on error
set -e

# Variables
ODOO_VERSION=18.0
ODOO_USER=odoo
ODOO_HOME=/opt/odoo
ODOO_CONF=/etc/odoo.conf
PYTHON_VERSION=3.10

echo "========== Updating system =========="
apt update && apt upgrade -y

echo "========== Installing dependencies =========="
apt install -y git python${PYTHON_VERSION} python3-pip build-essential wget   python3-venv python3-dev libxslt-dev libzip-dev libldap2-dev libsasl2-dev   libpq-dev libjpeg-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev   libssl-dev libffi-dev libxml2-dev zlib1g-dev libfreetype6-dev libjpeg8   libpq-dev libxrender1 libxext6 libx11-dev xfonts-75dpi xfonts-base   libtiff5-dev libopenjp2-7 libharfbuzz-dev libfribidi-dev libxcb1-dev

echo "========== Creating Odoo user and directories =========="
adduser --system --home=${ODOO_HOME} --group ${ODOO_USER} || true

echo "========== Cloning Odoo CE v18 =========="
git clone https://www.github.com/odoo/odoo --depth 1 --branch ${ODOO_VERSION} ${ODOO_HOME}

echo "========== Creating virtual environment =========="
python${PYTHON_VERSION} -m venv ${ODOO_HOME}/venv
${ODOO_HOME}/venv/bin/pip install -U pip setuptools wheel

echo "========== Installing Python requirements =========="
${ODOO_HOME}/venv/bin/pip install -r ${ODOO_HOME}/requirements.txt

echo "========== Creating odoo.conf =========="
cat <<EOF > ${ODOO_CONF}
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = ${ODOO_HOME}/addons
logfile = /var/log/odoo/odoo.log
EOF

chown ${ODOO_USER}:${ODOO_USER} ${ODOO_CONF}
chmod 640 ${ODOO_CONF}

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
User=${ODOO_USER}
Group=${ODOO_USER}
ExecStart=${ODOO_HOME}/venv/bin/python3 ${ODOO_HOME}/odoo-bin -c ${ODOO_CONF}
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

echo "========== Reloading and starting Odoo =========="
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo
systemctl status odoo --no-pager
