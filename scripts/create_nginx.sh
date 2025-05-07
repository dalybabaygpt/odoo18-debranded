#!/bin/bash

# Script: enable_ssl_realtime.sh
# Purpose: Adds SSL via Let's Encrypt + enables real-time WebSocket support for Odoo CE 18 using NGINX on Ubuntu 24.04

# ========= COLORS =========
GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

# ========= PROMPTS =========
echo -e "${GREEN}=== Odoo SSL + Real-Time WebSocket Enabler ===${NC}"
echo "Enter your domain name (e.g. erp.example.com):"
read -r DOMAIN_NAME

echo "Enter your email for Let's Encrypt registration (e.g. you@example.com):"
read -r CERTBOT_EMAIL

# ========= DOMAIN CHECK =========
echo -e "${GREEN}Checking if domain resolves...${NC}"
if ! ping -c 1 -W 2 "$DOMAIN_NAME" >/dev/null 2>&1; then
  echo -e "${RED}[ERROR] Domain $DOMAIN_NAME is not resolving!${NC}"
  echo "Make sure your domain is correctly pointing to this server."
  exit 1
fi

# ========= INSTALL DEPENDENCIES =========
echo -e "${GREEN}Installing NGINX and Certbot...${NC}"
apt install -y nginx certbot python3-certbot-nginx

# ========= CONFIGURE NGINX =========
echo -e "${GREEN}Configuring NGINX reverse proxy for Odoo...${NC}"
cat <<EOF > /etc/nginx/sites-available/odoo
server {
    listen 80;
    server_name $DOMAIN_NAME;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

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

    access_log /var/log/nginx/odoo_access.log;
    error_log /var/log/nginx/odoo_error.log;
}
EOF

ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
nginx -t && systemctl reload nginx

# ========= OBTAIN SSL =========
echo -e "${GREEN}Requesting Let's Encrypt certificate...${NC}"
if certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "$CERTBOT_EMAIL"; then
  echo -e "${GREEN}SSL successfully installed.${NC}"
else
  echo -e "${RED}SSL installation failed. Check domain and DNS settings.${NC}"
fi

# ========= CRON AUTO RENEW =========
echo -e "${GREEN}Adding auto-renewal for SSL...${NC}"
echo "0 3 * * * root certbot renew --quiet && systemctl reload nginx" > /etc/cron.d/odoo_ssl_renew

# ========= ODOO CONFIGURATION UPDATE =========
ODOO_CONF_FILE="/etc/odoo/odoo.conf"
if [ -f "$ODOO_CONF_FILE" ]; then
  sed -i "s/^proxy_mode *=.*/proxy_mode = True/" "$ODOO_CONF_FILE"
  grep -q "proxy_mode" "$ODOO_CONF_FILE" || echo "proxy_mode = True" >> "$ODOO_CONF_FILE"
  grep -q "longpolling_port" "$ODOO_CONF_FILE" || echo "longpolling_port = 8072" >> "$ODOO_CONF_FILE"
  echo -e "${GREEN}Odoo config updated for real-time and reverse proxy.${NC}"
else
  echo -e "${RED}Could not find odoo.conf. Please make sure Odoo is installed correctly.${NC}"
fi

# ========= FINAL MESSAGE =========
echo -e "${GREEN}Done. Your Odoo is now available at: https://$DOMAIN_NAME${NC}"
echo "Real-time connection and SSL are now enabled."
