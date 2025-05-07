#!/bin/bash

# ========== CONFIG ==========
OE_USER="odoo"
OE_HOME="/opt/$OE_USER"
OE_VERSION="18.0"
INSTALL_WKHTMLTOPDF="True"
CUSTOM_ADDONS_REPO="https://github.com/dalybabaygpt/odoo18-debranded"
CUSTOM_ADDONS_BRANCH="main"
# =============================

echo "STEP 1: Updating and Installing Dependencies"
apt update && apt upgrade -y
apt install -y python3-pip build-essential wget git python3-dev python3-venv \
  libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools \
  node-less libjpeg-dev libpq-dev libxml2-dev libffi-dev libssl-dev \
  libxrender1 libxext6 xfonts-75dpi xfonts-base libjpeg8-dev zlib1g-dev \
  fonts-noto fonts-noto-cjk unzip nginx curl

echo "STEP 2: Creating Odoo User"
useradd -m -d $OE_HOME -U -r -s /bin/bash $OE_USER

echo "STEP 3: Installing and Activating PostgreSQL"
apt install -y postgresql
su - postgres -c "createuser -s $OE_USER" || true

echo "STEP 4: Cloning Odoo CE 18 Source"
mkdir -p $OE_HOME && cd $OE_HOME
git clone https://github.com/odoo/odoo --depth 1 --branch $OE_VERSION --single-branch .
python3 -m venv venv
source venv/bin/activate
pip install wheel
pip install -r requirements.txt

echo "STEP 5: Installing Wkhtmltopdf"
if [ "$INSTALL_WKHTMLTOPDF" = "True" ]; then
  wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.focal_amd64.deb
  apt install -y ./wkhtmltox_0.12.6-1.focal_amd64.deb
fi

echo "STEP 6: Cloning Custom Addons"
mkdir -p $OE_HOME/custom_addons
cd $OE_HOME/custom_addons
git init
git remote add origin $CUSTOM_ADDONS_REPO
git config core.sparseCheckout true
echo "custom_addons/" >> .git/info/sparse-checkout
git pull origin $CUSTOM_ADDONS_BRANCH

echo "STEP 7: Creating Configuration File"
cat <<EOF > /etc/odoo.conf
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = $OE_HOME/addons,$OE_HOME/custom_addons/custom_addons
logfile = /var/log/odoo/odoo.log
log_level = info
workers = 2
limit_memory_soft = 640000000
limit_memory_hard = 760000000
limit_request = 8192
limit_time_cpu = 60
limit_time_real = 120
EOF

echo "STEP 8: Creating Odoo Service"
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=$OE_USER
Group=$OE_USER
ExecStart=$OE_HOME/venv/bin/python3 $OE_HOME/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

echo "STEP 9: Starting Odoo Service"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

echo "✅ INSTALLATION COMPLETE"
echo "Access your Odoo 18 via: http://<your-server-ip>:8069"
