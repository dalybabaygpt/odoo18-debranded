#!/bin/bash

ODOO_CONF="/etc/odoo/odoo.conf"
NGINX_CONF="/etc/nginx/sites-available/odoo"
NGINX_ENABLED="/etc/nginx/sites-enabled/odoo"

echo "Fixing real-time connection for Odoo CE 18..."

# Step 1: Ensure port 8072 is allowed
ufw allow 8072/tcp
echo "✅ Port 8072 opened in UFW."

# Step 2: Add longpolling_port to odoo.conf if not present
if ! grep -q "longpolling_port" "$ODOO_CONF"; then
  echo "longpolling_port = 8072" >> "$ODOO_CONF"
  echo "✅ Added 'longpolling_port = 8072' to odoo.conf."
else
  echo "✔️ 'longpolling_port' already present in odoo.conf"
fi

# Step 3: Update Nginx config if exists
if [ -f "$NGINX_CONF" ]; then
  if ! grep -q "/longpolling/" "$NGINX_CONF"; then
    sed -i "/location \/ {/a \\\n    location /longpolling/ {\n        proxy_pass http://127.0.0.1:8072/;\n        proxy_set_header Host \$host;\n        proxy_set_header X-Real-IP \$remote_addr;\n        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto \$scheme;\n    }\n" "$NGINX_CONF"
    echo "✅ Added longpolling config to nginx."
    nginx -t && systemctl restart nginx
  else
    echo "✔️ Nginx already has /longpolling/ route."
  fi
else
  echo "⚠️ Nginx config not found at $NGINX_CONF – skipping Nginx update."
fi

# Step 4: Restart Odoo
systemctl restart odoo
echo "✅ Odoo restarted."

echo "✅ Real-time fix applied. Check Discuss module for connection status."
