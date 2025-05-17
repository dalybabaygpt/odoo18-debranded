#!/bin/bash

echo "📦 Starting full ERP snapshot..."

# Set snapshot folder inside Backup directory
NOW=$(date +"%Y%m%d_%H%M%S")
SNAPSHOT_DIR="/Users/daly/Documents/GitHub/ERP18-debranded/Backup/snapshot_$NOW"
mkdir -p "$SNAPSHOT_DIR"

# Auto-detect Docker containers
WEB=$(docker ps --filter "name=web" --format "{{.Names}}" | head -n 1)
DB=$(docker ps --filter "name=db" --format "{{.Names}}" | head -n 1)

echo "🧠 Detected containers:"
echo "WEB = $WEB"
echo "DB  = $DB"

# Backup database (must be a single line)
echo "📝 Dumping PostgreSQL database..."
docker exec -t "$DB" pg_dump -U odoo odoo > "$SNAPSHOT_DIR/odoo_db_backup.sql"

# Backup filestore
echo "📁 Copying filestore from container..."
docker cp "$WEB:/var/lib/odoo/filestore" "$SNAPSHOT_DIR/filestore"

# Backup metadata
echo "📄 Writing backup info..."
echo "Backup Date: $(date)" > "$SNAPSHOT_DIR/info.txt"
echo "Web Container: $WEB" >> "$SNAPSHOT_DIR/info.txt"
echo "DB Container: $DB" >> "$SNAPSHOT_DIR/info.txt"

echo "✅ Backup completed and saved to: $SNAPSHOT_DIR"
