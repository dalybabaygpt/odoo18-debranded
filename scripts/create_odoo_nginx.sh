#!/bin/bash

# Bulletproof Full Automated Odoo nginx config generator + SSL + Live Reload
# By ChatGPT for @resto.prestiaclub.com and future domains

clear
echo "\n==============================="
echo " Bulletproof Odoo Nginx Setup (Full Auto) "
echo "===============================\n"

read -p "Enter your domain (example: resto.prestiaclub.com): " domain
read -p "Enter your Odoo backend IP (default 127.0.0.1): " backend_ip

# Default if empty
backend_ip=${backend_ip:-127.0.0.1}

# Path setup
NGINX_AVAILABLE="/etc/nginx/sites-available/${domain}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${domain}"

# Install Certbot if missing
echo "\nChecking Certbot installation..."
if ! command -v certbot &> /dev/null
then
    echo "Certbot not found. Installing Certbot..."
    sudo apt update && sudo apt install -y certbot python3-certbot-nginx
fi

# Create a basic dummy nginx config for certbot precheck
echo "\nPreparing temporary nginx config for SSL..."
cat > $NGINX_AVAILABLE <<EOF
server {
    listen 80;
    server_name ${domain};
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

# Enable site and reload nginx
ln -sf $NGINX_AVAILABLE $NGINX_ENABLED
sudo nginx -t && sudo systemctl reload nginx

# Issue SSL Certificate automatically
echo "\nIssuing SSL certificate with Certbot..."
sudo certbot --nginx -d ${domain} --non-interactive --agree-tos --email admin@${domain} 
--redirect

# Generate final nginx config
echo "\nGenerating final nginx config for Odoo..."
cat > $NGINX_AVAILABLE <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    server_name ${domain};

    client_max_body_size 100M;

    listen 443 ssl http2;
    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    proxy_read_timeout 86400s;
    proxy_connect_timeout 86400s;
    proxy_send_timeout 86400s;
    send_timeout 86400s;
    proxy_buffering off;
    proxy_request_buffering off;

    location / {
        proxy_pass http://${backend_ip}:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }

    location /longpolling {
        proxy_pass http://${backend_ip}:8072;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    location /websocket {
        proxy_pass http://${backend_ip}:8072;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}

server {
    listen 80;
    server_name ${domain};
    return 301 https://\$host\$request_uri;
}
EOF

# Final Reload
sudo nginx -t
sudo systemctl reload nginx

# Done!
echo "\n====================================="
echo " All Done! "
echo " - Nginx configured for domain: ${domain}"
echo " - SSL installed and forced HTTPS"
echo " - Full Real-Time (WebSocket/Longpolling) support ready"
echo "=====================================\n"

