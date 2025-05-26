#!/bin/bash
# Script2: Auto-sync custom addons from GitHub and restart Odoo daily at 4AM

# Ensure custom_addons folder exists
REPO_DIR="/opt/custom_addons"
LOG_FILE="/var/log/odoo_git_sync.log"

if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning the custom addons repository..."
    git clone https://github.com/dalybabaygpt/ERP18-debranded.git "$REPO_DIR"
fi

# Create sync script
SYNC_SCRIPT="/opt/odoo/git_sync.sh"
cat << 'EOF' > "$SYNC_SCRIPT"
#!/bin/bash
cd /opt/custom_addons || exit
echo "====== $(date): Sync Started ======" >> /var/log/odoo_git_sync.log
git pull origin main >> /var/log/odoo_git_sync.log 2>&1
sudo systemctl restart odoo >> /var/log/odoo_git_sync.log 2>&1
echo "====== $(date): Sync Complete ======" >> /var/log/odoo_git_sync.log
EOF

chmod +x "$SYNC_SCRIPT"

# Schedule the sync script daily at 4AM
(crontab -l 2>/dev/null | grep -v "$SYNC_SCRIPT" ; echo "0 4 * * * $SYNC_SCRIPT") | crontab -

echo "✅ Script2 setup complete. Your server will auto-sync modules daily at 4AM."
