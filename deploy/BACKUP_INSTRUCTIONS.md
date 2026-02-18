# MusicSchoolApp Production Backup Instructions

This setup backs up your production Postgres database and uploads Docker volume.

## How it works
- Dumps the Postgres database from the running container.
- Archives the uploads Docker volume via the backend container.
- Stores both in a timestamped backup directory under `~/music_school_backups`.
- Keeps only the 10 most recent backups.

## Usage

1. Ensure Docker Compose is running with the updated `docker-compose.prod.yml` (with `uploads_data` volume).
2. Run the backup script:

```bash
bash deploy/backup_prod.sh
```

Backups will be stored in `~/music_school_backups/backup_<timestamp>/`.

## Scheduling (Optional)
To automate daily backups, add this line to your crontab (edit with `crontab -e`):

```
0 3 * * * bash /home/levitanus/gits/MusicSchoolApp/deploy/backup_prod.sh
```

This runs the backup every day at 3:00 AM.

## Restore
- To restore the database, use `psql` with the backup SQL file.
- To restore uploads, extract `uploads.tar.gz` and copy contents to the uploads volume (via backend container).

---
For questions or issues, see the script comments or contact the maintainer.
