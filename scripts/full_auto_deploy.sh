#!/bin/bash

set -e  # Exit immediately if any command fails

clear
echo "==============================="
echo " SmartERP Full Auto Deployment "
echo "==============================="

# Step 1: Install Odoo + PostgreSQL
echo "📦 Installing SmartERP system and dependencies..."
bash scripts/install_smarterp.sh

echo "✅ SmartERP system installation finished."

# Step 2: Ask user if he wants to configure Nginx + SSL now
read -p "🌐 Do you want to configure Nginx + SSL now? (y/n): " CONFIGURE_DOMAIN

if [[ "$CONFIGURE_DOMAIN" == "y" || "$CONFIGURE_DOMAIN" == "Y" ]]; then
    echo "⚡ Starting Nginx + SSL full setup..."
    bash scripts/create_odoo_nginx.sh
    echo "✅ Nginx + SSL setup finished."
else
    echo "ℹ️ Skipped Nginx + SSL setup. You can run bash scripts/create_odoo_nginx.sh manually later."
fi

echo ""
echo "========================================"
echo "✅ SmartERP Full Deployment Completed!"
echo "========================================"
echo "👉 If SSL configured: https://yourdomain.com"
echo "👉 If no domain yet: http://your-server-ip:8069"
echo "Default Login: admin / admin"
echo "========================================"
