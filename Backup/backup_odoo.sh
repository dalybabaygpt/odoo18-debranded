#!/bin/bash
echo "🔄 Starting ERP Backup..."

# Define backup folder with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR=~/Desktop/erp_backups/erp_$TIMESTAMP
mkdir -p $BACKUP_DIR

# Backup PostgreSQL database from Docker
echo "📦 Backing up PostgreSQL database..."
docker exec -t odoo18-local-db-1 pg_dump -U odoo odoo > $BACKUP_DIR/odoo_db_backup.sql

# Backup filestore
echo "📁 Copying filestore from Docker..."
docker cp odoo18-local-web-1:/var/lib/odoo/filestore $BACKUP_DIR/filestore

# Backup custom_addons folder from host
echo "📂 Saving custom addons..."
cp -r ~/Documents/GitHub/ERP18-debranded/custom_addons $BACKUP_DIR/custom_addons

echo "✅ Backup completed at $BACKUP_DIR"
