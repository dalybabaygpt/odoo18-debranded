#!/bin/bash

set -e  # Exit if error

clear
echo "==============================="
echo " SmartERP Full Install + Domain "
echo "==============================="

# Step 1: Install ERP system and dependencies
echo "📦 Installing SmartERP system and dependencies..."
bash scripts/install_smarterp.sh

echo "✅ SmartERP system installation finished."

# Step 2: Configure domain + SSL
read -p "🌐 Enter the client subdomain you want to create (example: client1): " SUBDOMAIN
read -p "🌐 Enter your main domain (example: mydomain.com): " MAINDOMAIN

CLIENT_DOMAIN="${SUBDOMAIN}.${MAINDOMAIN}"

# Safety check: Ping the domain to see if already exists
if ping -c 1 "$CLIENT_DOMAIN" &> /dev/null
then
    echo "❌ ERROR: Domain ${CLIENT_DOMAIN} already exists or is live. Stop now."
    exit 1
else
    echo "✅ Domain ${CLIENT_DOMAIN} is free. Proceeding..."
fi

echo "⚡ Starting Nginx + SSL full setup for ${CLIENT_DOMAIN}..."
bash scripts/create_odoo_nginx.sh "$CLIENT_DOMAIN"

echo "✅ Nginx + SSL configured for ${CLIENT_DOMAIN}"

# Step 3: Create default database
echo "⚙️ Creating default database..."

DBNAME="smarterp_${SUBDOMAIN}"

./odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin --config=/etc/odoo/odoo.conf \
 --database="$DBNAME" \
 --init=base \
 --save \
 --stop-after-init

# Step 4: Set admin/admin login
echo "🔐 Setting admin/admin credentials..."

sudo -u postgres psql -c "UPDATE res_users SET password_crypt = NULL, password = 'admin' WHERE id = 2;" "$DBNAME"

echo "✅ Database '$DBNAME' created with login admin/admin."

# Final summary
echo ""
echo "========================================"
echo "✅ SmartERP Full Deployment Completed!"
echo "========================================"
echo "👉 Access your ERP at: https://${CLIENT_DOMAIN}"
echo "👉 Login: admin / admin"
echo "========================================"
