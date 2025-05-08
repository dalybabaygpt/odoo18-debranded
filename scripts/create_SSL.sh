#!/bin/bash

# Script 2: NGINX + SSL + Real-time Fix for Odoo CE 18
# Prompts for domain/email, enables WebSocket, real-time, and Let's Encrypt SSL with Cloudflare support

# ========= PROMPT =========
echo -e "\033[1;32mStarting Script 2: Enable SSL and Real-Time...\033[0m"
echo "Enter your domain (e.g. erp.example.com):"
read -r DOMAIN
echo "Enter your email for Let's Encrypt registration:"
read -r EMAIL

# ========= CERTBOT INSTALL =========
echo -e "\033[1;32mInstalling Certbot & NGINX modules...\033[0m"
apt install -y certbot python3-certbot-nginx nginx

# ========= FIREWALL =========
echo -e "\033[1;32mEnsuring ports 80/443 are open...\033[0m"
ufw allow 80,443/tcp || true
ufw reload || true

# ========= CLOUDFLARE IPS =========
echo -e "\033[1;32mAllowing Cloudflare IP ranges...\033[0m"
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
  ufw allow from $ip to any port 443 proto tcp || true
  ufw allow from $ip to any port 80 proto tcp || true
done
ufw reload || true

# ========= NGINX CONFIG =========
echo -e "\033[1;32mCreating NGINX config for $DOMAIN...\033[0m"
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

ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
nginx -t && systemctl reload nginx

# ========= SSL VIA CERTBOT =========
echo -e "\033[1;32mRequesting SSL certificate via Certbot...\033[0m"
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL || true

# ========= ENABLE ODOO CONF REAL-TIME =========
echo -e "\033[1;32mEnabling proxy_mode, longpolling and workers in /etc/odoo/odoo.conf...\033[0m"
sed -i '/^proxy_mode/d' /etc/odoo/odoo.conf
sed -i '/^workers/d' /etc/odoo/odoo.conf
sed -i '/^gevent_port/d' /etc/odoo/odoo.conf
echo "proxy_mode = True" >> /etc/odoo/odoo.conf
echo "workers = 3" >> /etc/odoo/odoo.conf
echo "gevent_port = 8072" >> /etc/odoo/odoo.conf

# ========= RESTART SERVICES =========
echo -e "\033[1;32mRestarting Odoo and NGINX...\033[0m"
systemctl restart odoo
systemctl restart nginx

# ========= VERIFY =========
echo -e "\033[1;32m✅ All set. You can now access: https://$DOMAIN\033[0m"
echo -e "Real-time should be working. Check browser dev tools for WebSocket on /longpolling."
