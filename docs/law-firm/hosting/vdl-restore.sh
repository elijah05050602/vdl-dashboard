#!/usr/bin/env bash
# Restore a backup made by vdl-backup.sh. This REPLACES the current database and attachments.
# Usage: sudo vdl-restore /var/backups/vdl-dashboard/vdl-2026-12-01_0130.tar.gpg
set -euo pipefail

backup="${1:?usage: vdl-restore <backup.tar.gpg>}"
source /etc/vdl-backup.env
DB_NAME="${DB_NAME:-vdl_dashboard}"
ATTACHMENTS_DIR="${ATTACHMENTS_DIR:-/var/lib/vdl-dashboard/files}"

read -r -p "This replaces the live database and attachments with $backup. Type RESTORE to continue: " answer
[[ "$answer" == "RESTORE" ]] || { echo "Cancelled."; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
gpg --batch --pinentry-mode loopback --passphrase-fd 3 -d "$backup" 3<<<"$BACKUP_PASSPHRASE" | tar -C "$work" -xf -

systemctl stop vdl-dashboard-web vdl-dashboard-worker
sudo -u postgres dropdb --if-exists "$DB_NAME"
sudo -u postgres createdb -O vdl "$DB_NAME"
sudo -u postgres pg_restore --no-owner --role=vdl -d "$DB_NAME" "$work/db.dump"

mv "$ATTACHMENTS_DIR" "$ATTACHMENTS_DIR.before-restore-$(date +%s)"
tar -C "$(dirname "$ATTACHMENTS_DIR")" -xzf "$work/files.tar.gz"
chown -R vdl:vdl "$ATTACHMENTS_DIR"

systemctl start vdl-dashboard-web vdl-dashboard-worker
echo "Restored. The old attachments folder was kept next to the new one; delete it once you have checked."
