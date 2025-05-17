#!/bin/bash
echo "♻️ Starting ERP Restore..."

# Ask user to choose backup directory
echo "📁 Enter full path to backup folder (e.g., ~/Desktop/erp_backups/erp_YYYYMMDD_HHMMSS):"
read BACKUP_DIR

# Restore PostgreSQL database
echo "📦 Restoring PostgreSQL database..."
cat $BACKUP_DIR/odoo_db_backup.sql | docker exec -i odoo18-local-db-1 psql -U odoo odoo

# Restore filestore
echo "📁 Restoring filestore..."
docker cp $BACKUP_DIR/filestore odoo18-local-web-1:/var/lib/odoo/

# Restore custom_addons (optional if synced to GitHub)
echo "📂 Restoring custom addons..."
cp -r $BACKUP_DIR/custom_addons ~/Documents/GitHub/ERP18-debranded/

# Restart Docker
echo "🔄 Restarting Docker..."
docker restart odoo18-local-web-1

echo "✅ Restore completed!"
