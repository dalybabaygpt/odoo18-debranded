#!/bin/bash

# Define variables
ODOO_CONF="/etc/odoo/odoo.conf"
NGINX_CONF="/etc/nginx/sites-available/odoo"
NGINX_LINK="/etc/nginx/sites-enabled/odoo"

echo "🔧 Updating odoo.conf with gevent settings..."
# Remove longpolling_port if it exists
sed -i '/longpolling_port/d' $ODOO_CONF

# Add gevent_port if not present
if ! grep -q "gevent_port" $ODOO_CONF; then
    echo "gevent_port = 8072" >> $ODOO_CONF
fi

# Ensure proxy_mode is set to True
if ! grep -q "proxy_mode" $ODOO_CONF; then
    echo "proxy_mode = True" >> $ODOO_CONF
fi

# Set workers to 4 if not already set
if ! grep -q "workers" $ODOO_CONF; then
    echo "workers = 4" >> $ODOO_CONF
fi

echo "🔧 Configuring NGINX with WebSocket support..."
cat <<EOF > $NGINX_CONF
upstream odoo {
    server 127.0.0.1:8069;
}
upstream odoochat {
    server 127.0.0.1:8072;
}
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}
server {
    listen 80;
    server_name _;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    location / {
        proxy_pass http://odoo;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }

    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }

    access_log /var/log/nginx/odoo_access.log;
    error_log /var/log/nginx/odoo_error.log;
}
EOF

echo "🔧 Enabling NGINX configuration..."
ln -sf $NGINX_CONF $NGINX_LINK

echo "🔧 Allowing gevent port 8072 through UFW..."
ufw allow 8072/tcp

echo "🔁 Restarting services..."
nginx -t && systemctl reload nginx
systemctl restart odoo

echo "✅ Odoo real-time connection fix applied. Verifying port 8072..."
ss -tuln | grep :8072 && echo "✅ Port 8072 is listening!" || echo "❌ Odoo not listening on 8072"
