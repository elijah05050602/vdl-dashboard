#!/usr/bin/env bash
# Update the VDL Dashboard to the latest code on the dev branch.
# Run as root: sudo vdl-update   (take a backup first; the script does it for you)
set -euo pipefail

APP=/opt/vdl-dashboard
BRANCH="${BRANCH:-dev}"
as_vdl() { sudo -iu vdl bash -lc "set -a; source /etc/vdl-dashboard.env; set +a; cd $APP; $*"; }

/usr/local/sbin/vdl-backup
as_vdl "git fetch origin $BRANCH && git checkout -q $BRANCH && git reset -q --hard origin/$BRANCH"
as_vdl "bundle install && npm ci"
as_vdl "bundle exec rails assets:precompile"
systemctl stop vdl-dashboard-worker
as_vdl "bundle exec rails db:migrate db:seed"
systemctl restart vdl-dashboard-web vdl-dashboard-worker
echo "Updated to $(as_vdl 'git log -1 --format=%h\ %s')"
