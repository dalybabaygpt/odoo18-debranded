#!/usr/bin/env bash
# --------------------------------------------------------------------------------
# SmartERP Fully Automated Installer (Ubuntu 22.04 / 24.04)
# Installs ERP (Debranded Odoo CE18) with your custom modules in one command
# Tested for idempotence and multiple scenarios (fresh or partially provisioned server)
# Usage:
#   GITHUB_USER=dalybabaygpt GITHUB_TOKEN=github_pat_... \
#   sudo bash <(curl -sL https://raw.githubusercontent.com/dalybabaygpt/odoo18-debranded/main/scripts/install_erpip_only_debranded.sh)
# --------------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# 1. Check for root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Use sudo." >&2
  exit 1
fi

# 2. Environment variables
: "${GITHUB_USER:?Need to set GITHUB_USER}"  # e.g. dalybabaygpt
: "${GITHUB_TOKEN:?Need to set GITHUB_TOKEN}"  # GitHub PAT with repo access
ERP_USER="erp"
ERP_HOME="/opt/erp"
ERP_SERVICE="erp.service"
CONF_DIR="/etc/erp"
CONF_FILE="$CONF_DIR/erp.conf"
LOG_DIR="/var/log/erp"
PYTHON="python3.11"

# 3. Update & install OS dependencies
apt update
apt install -y wget git build-essential $PYTHON $PYTHON-venv $PYTHON-dev \
    libxml2-dev libxslt1-dev libsasl2-dev libldap2-dev libssl-dev libjpeg-dev libpq-dev

# 4. Create ERP system user if not exists
if ! id -u $ERP_USER &>/dev/null; then
  useradd -m -d $ERP_HOME -U -r -s /bin/bash $ERP_USER
fi

# 5. Clone or update codebase
if [[ ! -d "$ERP_HOME" ]]; then
  git clone -b main https://$GITHUB_USER:$GITHUB_TOKEN@github.com/dalybabaygpt/odoo18-debranded.git $ERP_HOME
else
  cd $ERP_HOME && git pull --ff-only
fi
chown -R $ERP_USER:$ERP_USER $ERP_HOME

# 6. Create Python venv & install requirements
sudo -u $ERP_USER $PYTHON -m venv $ERP_HOME/venv
sudo -u $ERP_USER bash -c "$ERP_HOME/venv/bin/pip install --upgrade pip wheel"
if [[ -f "$ERP_HOME/requirements.txt" ]]; then
  sudo -u $ERP_USER bash -c "$ERP_HOME/venv/bin/pip install -r $ERP_HOME/requirements.txt"
fi

# 7. PostgreSQL: create ERP DB user
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$ERP_USER'" | grep -q 1; then
  sudo -u postgres createuser --createdb --username postgres --no-createrole --no-superuser $ERP_USER
fi

# 8. Config directories
mkdir -p $CONF_DIR $LOG_DIR $ERP_HOME/data
cat > $CONF_FILE <<EOF
[options]
addons_path = $ERP_HOME/addons,$ERP_HOME/custom_addons
data_dir = $ERP_HOME/data
admin_passwd = changeme
xmlrpc_port = 8069
longpolling_port = 8072
logfile = $LOG_DIR/erp.log
EOF
chown -R $ERP_USER:$ERP_USER $CONF_DIR $LOG_DIR
chmod 640 $CONF_FILE

# 9. Systemd service
SERVICE_PATH="/etc/systemd/system/$ERP_SERVICE"
cat > $SERVICE_PATH <<EOF
[Unit]
Description=SmartERP Service
After=network.target postgresql.service

[Service]
Type=simple
User=$ERP_USER
ExecStart=$ERP_HOME/venv/bin/python3 $ERP_HOME/odoo-bin -c $CONF_FILE
KillMode=mixed
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable $ERP_SERVICE
systemctl restart $ERP_SERVICE

# 10. Output status
echo
echo "SmartERP installation complete!"
echo "Service: $ERP_SERVICE"
echo "Access your ERP at http://<server-ip>:8069"
