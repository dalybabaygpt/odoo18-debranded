#!/bin/bash
# 🚀 Full SmartERP + Nginx SSL deployer

clear
echo "==============================="
echo " SmartERP Full Auto Deployment "
echo "===============================\n"

# Install Odoo SmartERP
echo "📦 Installing Odoo SmartERP..."
bash scripts/install_smarterp.sh

# Ask if user wants SSL + domain configuration
read -p "🌐 Do you want to immediately configure Nginx + SSL? (y/n): " CONFIGURE_DOMAIN

if [[ "$CONFIGURE_DOMAIN" == "y" ]]; then
  echo "⚡ Setting up Nginx + SSL..."
  bash scripts/create_odoo_nginx.sh
else
  echo "ℹ️ Skipped SSL setup. You can run bash scripts/create_odoo_nginx.sh later when 
ready."
fi

echo "\n✅ SmartERP is fully deployed!"

