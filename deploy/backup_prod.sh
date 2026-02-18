#!/bin/bash
# Backup script for MusicSchoolApp production
# Dumps Postgres DB and archives uploads Docker volume
# Keeps only 10 most recent backups

set -euo pipefail

BACKUP_ROOT="$HOME/music_school_backups"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"
COMPOSE_FILE="$(dirname "$0")/docker-compose.prod.yml"

mkdir -p "$BACKUP_DIR"

# Get container IDs
DB_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q db)
BACKEND_CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q backend)

# 1. Backup Postgres DB
echo "Backing up Postgres database..."
docker exec "$DB_CONTAINER" pg_dump -U klavier klavierdb > "$BACKUP_DIR/db_backup.sql"

# 2. Archive uploads Docker volume via backend container
echo "Archiving uploads Docker volume..."
docker exec "$BACKEND_CONTAINER" tar -czf - -C /uploads . > "$BACKUP_DIR/uploads.tar.gz"

# 3. Rotate old backups (keep only 10 most recent)
cd "$BACKUP_ROOT"
ls -dt backup_* | tail -n +11 | xargs -r rm -rf

echo "Backup complete: $BACKUP_DIR"
