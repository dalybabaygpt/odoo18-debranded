#!/bin/bash

# Script 2: NGINX + SSL + Real-time Fix for Odoo CE 18
# Automatically enables Let's Encrypt SSL, Cloudflare support, and real-time for any domain

echo -e "\033[1;32mStarting Script 2: Enable SSL and Real-Time...\033[0m"
read -p "Enter your domain (e.g. erp.example.com): " DOMAIN
read -p "Enter your email for Let's Encrypt registration: " EMAIL

# ========= DEPENDENCIES =========
echo -e "\033[1;32mInstalling Certbot & NGINX modules...\033[0m"
apt update && apt install -y certbot python3-certbot-nginx nginx

# ========= FIREWALL =========
echo -e "\033[1;32mEnsuring ports 80/443 are open...\033[0m"
ufw allow 80,443/tcp || true
ufw reload || true

# ========= CLOUDFLARE SUPPORT =========
echo -e "\033[1;32mAllowing Cloudflare IP ranges...\033[0m"
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
  ufw allow from $ip to any port 443 proto tcp || true
  ufw allow from $ip to any port 80 proto tcp || true
done
ufw reload || true

# ========= TEMP HTTP NGINX BLOCK (for certbot to work) =========
echo -e "\033[1;32mCreating temporary HTTP-only NGINX config for $DOMAIN...\033[0m"
cat <<EOF > /etc/nginx/sites-available/odoo
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
nginx -t && systemctl restart nginx

# ========= GET SSL CERTIFICATE =========
echo -e "\033[1;32mRequesting Let's Encrypt certificate for $DOMAIN...\033[0m"
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# ========= GET REQUIRED SSL FILES =========
echo -e "\033[1;32mFetching missing Certbot SSL config files if needed...\033[0m"
mkdir -p /etc/letsencrypt
if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
  curl -fsSL https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf -o /etc/letsencrypt/options-ssl-nginx.conf
fi

if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
  curl -fsSL https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem -o /etc/letsencrypt/ssl-dhparams.pem
fi

# ========= FINAL FULL SSL NGINX CONFIG =========
echo -e "\033[1;32mCreating full HTTPS + WebSocket NGINX config...\033[0m"
cat <<EOF > /etc/nginx/sites-available/odoo
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    access_log /var/log/nginx/odoo_access.log;
    error_log /var/log/nginx/odoo_error.log;

    proxy_read_timeout 900;
    proxy_connect_timeout 900;
    proxy_send_timeout 900;
    send_timeout 900;
    client_max_body_size 200M;

    gzip on;
    gzip_types text/css text/scss application/javascript application/json image/svg+xml;
    gzip_min_length 256;

    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://127.0.0.1:8069;
    }

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_buffering off;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:8072;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    location /websocket {
        proxy_pass http://127.0.0.1:8072;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_buffering off;
    }
}
EOF

nginx -t && systemctl restart nginx

# ========= ENABLE ODOO CONFIGS =========
echo -e "\033[1;32mEnabling proxy_mode, longpolling, and workers in /etc/odoo/odoo.conf...\033[0m"
sed -i '/^proxy_mode/d' /etc/odoo/odoo.conf
sed -i '/^workers/d' /etc/odoo/odoo.conf
sed -i '/^gevent_port/d' /etc/odoo/odoo.conf
echo "proxy_mode = True" >> /etc/odoo/odoo.conf
echo "workers = 3" >> /etc/odoo/odoo.conf
echo "gevent_port = 8072" >> /etc/odoo/odoo.conf

# ========= RESTART ODOO =========
echo -e "\033[1;32mRestarting Odoo and verifying ports...\033[0m"
systemctl restart odoo
ss -tuln | grep -E '8069|8072'

echo -e "\n✅ Installation finished!"
echo -e "→ Access your ERP at: https://$DOMAIN"
echo -e "→ Real-time features (WebSocket) are enabled.\n"
