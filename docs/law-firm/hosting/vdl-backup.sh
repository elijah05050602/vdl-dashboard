#!/usr/bin/env bash
# Nightly encrypted backup of the VDL Dashboard database and attachments.
# Install: sudo install -m 750 vdl-backup.sh /usr/local/sbin/vdl-backup
# Cron:    see vdl-backup.cron
# Needs:   /etc/vdl-backup.env (chmod 600) with BACKUP_PASSPHRASE, and optionally RCLONE_REMOTE.
set -euo pipefail

source /etc/vdl-backup.env
: "${BACKUP_PASSPHRASE:?set BACKUP_PASSPHRASE in /etc/vdl-backup.env}"
DB_NAME="${DB_NAME:-vdl_dashboard}"
ATTACHMENTS_DIR="${ATTACHMENTS_DIR:-/var/lib/vdl-dashboard/files}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/vdl-dashboard}"
KEEP_DAYS="${KEEP_DAYS:-14}"

stamp="$(TZ=Asia/Manila date +%Y-%m-%d_%H%M)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

sudo -u postgres pg_dump --format=custom "$DB_NAME" > "$work/db.dump"
tar -C "$(dirname "$ATTACHMENTS_DIR")" -czf "$work/files.tar.gz" "$(basename "$ATTACHMENTS_DIR")"
tar -C "$work" -cf - db.dump files.tar.gz \
  | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 \
        --symmetric --cipher-algo AES256 -o "$BACKUP_DIR/vdl-$stamp.tar.gpg" 3<<<"$BACKUP_PASSPHRASE"

find "$BACKUP_DIR" -name 'vdl-*.tar.gpg' -mtime +"$KEEP_DAYS" -delete

if [[ -n "${RCLONE_REMOTE:-}" ]]; then
  rclone copy "$BACKUP_DIR/vdl-$stamp.tar.gpg" "$RCLONE_REMOTE"
fi

echo "Backup written: $BACKUP_DIR/vdl-$stamp.tar.gpg"
