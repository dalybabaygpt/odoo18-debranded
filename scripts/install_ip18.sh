#!/bin/bash

# Odoo CE 18 Auto Installer for Ubuntu 24.04
# Fully debranded + Custom addons path support
# Prompt for PostgreSQL password during install

# ========= VARIABLES =========
ODOO_VERSION=18.0
ODOO_USER=odoo
ODOO_HOME=/opt/odoo
ODOO_CONF=/etc/odoo/odoo.conf
CUSTOM_ADDONS_PATH="$ODOO_HOME/custom_addons"
ODOO_SERVICE_FILE=/etc/systemd/system/odoo.service
LOG_PATH=/var/log/odoo

# ========= COLORS =========
GREEN="\033[1;32m"
NC="\033[0m"

# ========= PROMPT =========
echo -e "${GREEN}Starting Odoo CE 18 Installer for Ubuntu 24.04...${NC}"
echo "Please enter a password for the PostgreSQL user '$ODOO_USER':"
read -s POSTGRES_PASSWORD

# ========= SYSTEM UPDATE =========
echo -e "${GREEN}Updating system...${NC}"
apt update && apt upgrade -y

# ========= DEPENDENCIES =========
echo -e "${GREEN}Installing dependencies...${NC}"
apt install -y git python3-pip build-essential wget python3-dev python3-venv \
libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools \
node-less libjpeg-dev libpq-dev libxml2-dev zlib1g-dev libffi-dev \
libssl-dev libyaml-dev libopenblas-dev liblcms2-dev libblas-dev \
libatlas-base-dev libwebp-dev libtiff-dev libxrender1 xfonts-75dpi \
xfonts-base libjpeg8-dev gdebi unzip net-tools

# ========= POSTGRESQL =========
echo -e "${GREEN}Installing PostgreSQL...${NC}"
apt install -y postgresql

# ========= CREATE USER =========
echo -e "${GREEN}Creating system user and PostgreSQL user...${NC}"
adduser --system --home=$ODOO_HOME --group $ODOO_USER || true
su - postgres -c "psql -c \"DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$ODOO_USER') THEN CREATE ROLE $ODOO_USER WITH LOGIN PASSWORD '$POSTGRES_PASSWORD'; END IF; END \$\$;\""
su - postgres -c "psql -c \"ALTER ROLE $ODOO_USER CREATEDB;\""

# ========= INSTALL ODOO =========
echo -e "${GREEN}Cloning Odoo source...${NC}"
mkdir -p $CUSTOM_ADDONS_PATH
cd /opt
if [ ! -d "$ODOO_HOME/odoo" ]; then
  git clone https://www.github.com/odoo/odoo --depth 1 --branch $ODOO_VERSION --single-branch $ODOO_HOME/odoo
fi

echo -e "${GREEN}Creating Python virtualenv...${NC}"
cd $ODOO_HOME
apt install -y python3-venv
python3 -m venv venv
source venv/bin/activate
pip3 install wheel
pip3 install -r odoo/requirements.txt

# ========= CONFIG FILE =========
echo -e "${GREEN}Creating config file...${NC}"
mkdir -p /etc/odoo
mkdir -p $LOG_PATH
cat <<EOF > $ODOO_CONF
[options]
admin_passwd = Time2fly@123
addons_path = $ODOO_HOME/odoo/addons,$CUSTOM_ADDONS_PATH
db_host = False
db_port = False
db_user = $ODOO_USER
db_password = $POSTGRES_PASSWORD
logfile = $LOG_PATH/odoo.log
logrotate = True
log_level = info
xmlrpc_port = 8069
EOF

chown $ODOO_USER:$ODOO_USER $ODOO_CONF
chmod 640 $ODOO_CONF

# ========= SYSTEMD SERVICE =========
echo -e "${GREEN}Creating systemd service...${NC}"
cat <<EOF > $ODOO_SERVICE_FILE
[Unit]
Description=Odoo
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python3 $ODOO_HOME/odoo/odoo-bin -c $ODOO_CONF
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

chmod 644 $ODOO_SERVICE_FILE
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

# ========= DONE =========
echo -e "${GREEN}Odoo CE 18 installation complete.${NC}"
echo "Access it via: http://your-server-ip:8069"
echo "Database Master Password: Time2fly@123"
echo "Custom Addons Folder: $CUSTOM_ADDONS_PATH"
