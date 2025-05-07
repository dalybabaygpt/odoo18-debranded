#!/bin/bash

# Odoo CE 18 Auto Installer for Ubuntu 24.04
# Fully debranded + Custom addons path support + optional NGINX/SSL + real-time config + domain prompt + email prompt + auto SSL renewal

# ========= VARIABLES =========
ODOO_VERSION=18.0
ODOO_USER=odoo
ODOO_HOME=/opt/odoo
ODOO_CONF=/etc/odoo/odoo.conf
CUSTOM_ADDONS_PATH="$ODOO_HOME/custom_addons"
ODOO_SERVICE_FILE=/etc/systemd/system/odoo.service
LOG_PATH=/var/log/odoo
NGINX_CONF_PATH=/etc/nginx/sites-available/odoo
NGINX_ENABLED_PATH=/etc/nginx/sites-enabled/odoo

# ========= COLORS =========
GREEN="\033[1;32m"
NC="\033[0m"

# ========= PROMPT =========
echo -e "${GREEN}Starting Odoo CE 18 Installer for Ubuntu 24.04...${NC}"
echo "Please enter a password for the PostgreSQL user '$ODOO_USER':"
read -s POSTGRES_PASSWORD
echo "Please enter a master admin password for Odoo (leave blank for default 'Time2fly@123'):"
read -s ADMIN_PASSWORD
ADMIN_PASSWORD=${ADMIN_PASSWORD:-Time2fly@123}
echo "Do you want to install NGINX + SSL + real-time connection support (y/n)?"
read -r INSTALL_NGINX
if [ "$INSTALL_NGINX" = "y" ]; then
  echo "Enter your domain name (e.g. erp.example.com):"
  read -r DOMAIN_NAME
  echo "Enter your email for Let's Encrypt SSL registration (e.g. you@example.com):"
  read -r CERTBOT_EMAIL
fi

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
xfonts-base libjpeg8-dev gdebi unzip net-tools curl software-properties-common

# ========= POSTGRESQL =========
echo -e "${GREEN}Installing PostgreSQL...${NC}"
apt install -y postgresql

# ========= CREATE USER =========
echo -e "${GREEN}Creating system user and PostgreSQL user...${NC}"
adduser --system --home=$ODOO_HOME --group $ODOO_USER || true
su - postgres -c "psql -c \"DO \\\$\\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$ODOO_USER') THEN CREATE ROLE $ODOO_USER WITH LOGIN PASSWORD '$POSTGRES_PASSWORD'; END IF; END \\\$\\$;\""
su - postgres -c "psql -c \"ALTER ROLE $ODOO_USER CREATEDB;\""

# ========= INSTALL ODOO =========
echo -e "${GREEN}Cloning Odoo source...${NC}"
cd /opt
if [ ! -d "$ODOO_HOME/odoo" ]; then
  git clone https://www.github.com/odoo/odoo --depth 1 --branch $ODOO_VERSION --single-branch $ODOO_HOME/odoo
fi

# ========= CUSTOM ADDONS =========
echo -e "${GREEN}Cloning custom addons...${NC}"
if [ ! -d "$CUSTOM_ADDONS_PATH" ]; then
  git clone https://github.com/dalybabaygpt/odoo18-debranded.git /opt/odoo/tmprepo
  mv /opt/odoo/tmprepo/custom_addons $CUSTOM_ADDONS_PATH
  rm -rf /opt/odoo/tmprepo
  chown -R $ODOO_USER:$ODOO_USER $CUSTOM_ADDONS_PATH
fi

# ========= PYTHON VENV =========
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
admin_passwd = $ADMIN_PASSWORD
addons_path = $ODOO_HOME/odoo/addons,$CUSTOM_ADDONS_PATH
db_host = False
db_port = False
db_user = $ODOO_USER
db_password = $POSTGRES_PASSWORD
logfile = $LOG_PATH/odoo.log
logrotate = True
log_level = info
xmlrpc_port = 8069
proxy_mode = True
longpolling_port = 8072
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

# ========= NGINX + SSL + REALTIME =========
if [ "$INSTALL_NGINX" = "y" ]; then
  echo -e "${GREEN}Installing NGINX + enabling WebSocket real-time support...${NC}"
  apt install -y nginx certbot python3-certbot-nginx

  cat <<EOF > $NGINX_CONF_PATH
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }

    location /longpolling/ {
        proxy_pass http://127.0.0.1:8072/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    error_log  /var/log/nginx/odoo_error.log;
    access_log /var/log/nginx/odoo_access.log;
}
EOF

  ln -s $NGINX_CONF_PATH $NGINX_ENABLED_PATH
  nginx -t && systemctl restart nginx

  echo -e "${GREEN}Obtaining Let's Encrypt SSL certificate...${NC}"
  certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos -m $CERTBOT_EMAIL

  echo -e "${GREEN}Setting up auto-renewal cron job...${NC}"
  echo "0 3 * * * root certbot renew --quiet && systemctl reload nginx" > /etc/cron.d/odoo_cert_renew
fi

# ========= DONE =========
echo -e "${GREEN}Odoo CE 18 installation complete.${NC}"
echo "Access it via: http://$DOMAIN_NAME"
echo "Database Master Password: $ADMIN_PASSWORD"
echo "Custom Addons Folder: $CUSTOM_ADDONS_PATH"
