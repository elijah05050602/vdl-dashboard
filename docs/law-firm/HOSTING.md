# Putting the VDL Dashboard online

This guide moves the dashboard from Van's PC (WSL, `http://localhost:3000`) to a server on the
internet, so every PC in the firm opens the same dashboard through the desktop app (`desktop/`).
Nothing here has been bought or set up yet. Follow it top to bottom when you are ready. Plan for
about half a day the first time.

The files this guide uses are in [`hosting/`](hosting/):

| File | Goes to | What it is |
|---|---|---|
| `vdl-dashboard.env.example` | `/etc/vdl-dashboard.env` | All the app's settings: address, database, email, 2FA |
| `vdl-dashboard-web.service`, `vdl-dashboard-worker.service` | `/etc/systemd/system/` | Keep the web server and background jobs running |
| `nginx-vdl-dashboard.conf` | `/etc/nginx/sites-available/vdl-dashboard` | HTTPS front door |
| `vdl-backup.sh`, `vdl-backup.env.example`, `vdl-backup.cron` | `/usr/local/sbin/vdl-backup`, `/etc/vdl-backup.env`, `/etc/cron.d/vdl-backup` | Nightly encrypted backup |
| `vdl-restore.sh` | `/usr/local/sbin/vdl-restore` | Restore a backup |
| `vdl-update.sh` | `/usr/local/sbin/vdl-update` | Update to the latest code |

Throughout, replace `dashboard.vdl-law.ph` with the firm's real address.

## 1. What you will end up with

```
 Office PCs (desktop app) ──HTTPS──▶ dashboard.vdl-law.ph ──▶ nginx ──▶ VDL Dashboard (Puma + job worker)
                                                                              │
                                                             PostgreSQL + attachments folder
                                                                              │
                                                      encrypted nightly backup ──▶ off-site storage
```

## 2. Recommended server

| | Recommended | Why |
|---|---|---|
| Region | **Singapore** | About 30 to 50 ms from Manila. Tokyo is the fallback. |
| Size | **4 GB RAM, 2 vCPU, 80 GB SSD** to start. Move to 8 GB above about 25 users. | OpenProject needs about 4 GB to run comfortably. |
| OS | **Ubuntu 24.04 LTS** | Supported until 2029, and what this guide is written for. |

### Providers and monthly cost

Prices are the providers' list prices in late 2026, so check them before buying. PHP at ₱58 to US$1.

| Provider | Plan | USD/month | PHP/month | Notes |
|---|---|---|---|---|
| **DigitalOcean** (recommended) | Basic Droplet 4 GB / 2 vCPU, SGP1 | ~$24 | ~₱1,400 | Easiest control panel. Weekly backups add 20% (~₱280). |
| AWS Lightsail | 4 GB / 2 vCPU, Singapore | ~$24 | ~₱1,400 | Good if the firm will use other AWS services. |
| Hetzner | CPX31 4 vCPU / 8 GB, Singapore | ~$20 | ~₱1,150 | Most RAM for the money, fewer guides for beginners. |
| Vultr | 4 GB High Performance, Singapore | ~$24 | ~₱1,400 | Similar to DigitalOcean. |

Other running costs:

| Item | USD/month | PHP/month |
|---|---|---|
| Domain: `.ph` about ₱2,000/year, `.com` about ₱700/year | ~$1 to $3 | ~₱60 to ₱170 |
| Off-site backup storage, Backblaze B2 or Wasabi, ~50 GB | ~$0.50 to $7 | ~₱30 to ₱400 |
| Email sending: Brevo free tier (300 emails/day), or the firm's Google Workspace / Microsoft 365 | $0 | ₱0 |
| HTTPS certificate (Let's Encrypt) | $0 | ₱0 |
| **Total** | **~$25 to $35** | **~₱1,500 to ₱2,000** |

One-time, optional: a code signing certificate for the desktop installer (see `desktop/README.md`),
about $200 to $400 a year (₱12,000 to ₱23,000), or Azure Trusted Signing at about $10 a month.

**Recommendation:** DigitalOcean, Singapore, 4 GB Droplet, with its weekly backups turned on *in
addition to* the nightly encrypted backups in section 7.

### Data privacy

Client files are personal and privileged information under the Data Privacy Act of 2012 (RA 10173).
Keeping the server in Singapore is allowed, but the firm stays responsible for it: use the encryption,
2FA and backups below, limit admin accounts, and record the server and the backup provider in the
firm's privacy documentation. Ask the firm's Data Protection Officer to sign off before go-live.

## 3. Before you start

1. **Buy the domain** (e.g. from dot.ph or Namecheap) and pick the address, e.g. `dashboard.vdl-law.ph`.
2. **Create an SSH key** on Van's PC, in WSL: `ssh-keygen -t ed25519`. The public key is in `~/.ssh/id_ed25519.pub`.
3. **Create the server**: Ubuntu 24.04, Singapore, 4 GB. Paste the public key as the login method. Do not choose a password login.
4. **Point the domain at it**: in the domain's DNS settings add an `A` record, name `dashboard`, value the server's IP address. It can take up to an hour to work.
5. **Get the email details** ready (section 6).

## 4. Production install

The fork has its own code (legal seed data, matter templates, PH holidays, branding), so it is installed
from this repository rather than from the stock OpenProject package. From WSL, log in with
`ssh root@<server-ip>`. Commands in sections 4.1, 4.2, 4.5 and later run as `root`.

### 4.1 Base system

```bash
timedatectl set-timezone Asia/Manila
apt update && apt -y upgrade
apt -y install git curl build-essential autoconf libssl-dev libyaml-dev libffi-dev zlib1g-dev \
  libpq-dev postgresql nginx certbot python3-certbot-nginx gnupg rclone ufw fail2ban unattended-upgrades
adduser --disabled-password --gecos "" vdl
mkdir -p /opt/vdl-dashboard /var/lib/vdl-dashboard/files
chown vdl:vdl /opt/vdl-dashboard /var/lib/vdl-dashboard/files

# Building the frontend needs more memory than 4 GB, so add 4 GB of swap.
fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt -y install nodejs
```

### 4.2 Database

```bash
sudo -u postgres createuser vdl
sudo -u postgres createdb -O vdl vdl_dashboard
```

### 4.3 Ruby 4.0.10 (as the `vdl` user)

```bash
su - vdl
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.profile
source ~/.profile
rbenv install 4.0.10      # takes 10 to 20 minutes
rbenv global 4.0.10
exit
```

### 4.4 Settings file (as root)

```bash
cp /dev/null /etc/vdl-dashboard.env
```

Paste the contents of [`hosting/vdl-dashboard.env.example`](hosting/vdl-dashboard.env.example) into
`/etc/vdl-dashboard.env` with `nano /etc/vdl-dashboard.env`, then fill it in:

- `SECRET_KEY_BASE`: the output of `openssl rand -hex 64`. Keep a copy offline. Never change it later.
- `OPENPROJECT_HOST__NAME`: the real address.
- The `SMTP` lines: see section 6.

```bash
chown vdl:vdl /etc/vdl-dashboard.env && chmod 600 /etc/vdl-dashboard.env
```

### 4.5 Get the code and build it (as `vdl`)

```bash
su - vdl
git clone --branch dev https://github.com/elijah05050602/vdl-dashboard.git /opt/vdl-dashboard
cd /opt/vdl-dashboard
set -a; source /etc/vdl-dashboard.env; set +a
bundle config set --local deployment true
bundle config set --local without 'development test'
bundle install
npm ci
bundle exec rails assets:precompile     # 15 to 30 minutes
bundle exec rails db:migrate db:seed    # also adds the PH holidays and matter templates
exit
```

### 4.6 Start it as a service (as root)

```bash
cp /opt/vdl-dashboard/docs/law-firm/hosting/vdl-dashboard-{web,worker}.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now vdl-dashboard-web vdl-dashboard-worker
systemctl status vdl-dashboard-web        # should say "active (running)"
curl -sI http://127.0.0.1:6000/login | head -1   # should print HTTP/1.1 200 OK
```

If it does not start, read the log with `journalctl -u vdl-dashboard-web -n 100`.

## 5. HTTPS with Let's Encrypt

```bash
# 1. Get the certificate while nginx still shows its default page on port 80.
certbot certonly --webroot -w /var/www/html -d YOUR.REAL.ADDRESS --agree-tos -m it@vdl-law.ph --no-eff-email

# 2. Switch nginx over to the dashboard.
cp /opt/vdl-dashboard/docs/law-firm/hosting/nginx-vdl-dashboard.conf /etc/nginx/sites-available/vdl-dashboard
sed -i 's/dashboard.vdl-law.ph/YOUR.REAL.ADDRESS/g' /etc/nginx/sites-available/vdl-dashboard
ln -s /etc/nginx/sites-available/vdl-dashboard /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# 3. Reload nginx after each automatic renewal.
printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

Open `https://YOUR.REAL.ADDRESS` in a browser: you should see the VDL sign-in page with a padlock.
Certbot renews the certificate by itself every 60 to 90 days. Check that renewal works with
`certbot renew --dry-run`.

## 6. Email (SMTP)

The dashboard sends sign-up invitations, password resets, notifications and the deadline digest.
Pick one and fill in the `OPENPROJECT_SMTP__*` lines in `/etc/vdl-dashboard.env`:

| Option | Address / port | User name | Password |
|---|---|---|---|
| **Brevo** (free, 300/day; recommended if the firm has no Workspace) | `smtp-relay.brevo.com` / 587 | the Brevo SMTP login | the Brevo SMTP key |
| Google Workspace | `smtp.gmail.com` / 587 | `dashboard@vdl-law.ph` | an app password (needs 2-Step Verification on that account) |
| Microsoft 365 | `smtp.office365.com` / 587 | the mailbox address | the mailbox password (SMTP AUTH must be on for that mailbox) |

Set `OPENPROJECT_MAIL__FROM` to an address on the firm's domain, and add the provider's SPF and DKIM
records to the domain's DNS (each provider shows the exact records), so emails do not land in spam.

Then `systemctl restart vdl-dashboard-web vdl-dashboard-worker`, sign in as admin, and send a test
email from **Administration > Emails and notifications**.

## 7. Encrypted daily backups

Each night at 1:30 AM Manila time the backup script dumps the database and the attachments folder,
encrypts them with AES-256 using a passphrase only the firm holds, keeps 14 days on the server and
copies each one off-site.

```bash
install -m 750 /opt/vdl-dashboard/docs/law-firm/hosting/vdl-backup.sh  /usr/local/sbin/vdl-backup
install -m 750 /opt/vdl-dashboard/docs/law-firm/hosting/vdl-restore.sh /usr/local/sbin/vdl-restore
install -m 600 /opt/vdl-dashboard/docs/law-firm/hosting/vdl-backup.env.example /etc/vdl-backup.env
nano /etc/vdl-backup.env          # set BACKUP_PASSPHRASE (e.g. openssl rand -base64 32) and RCLONE_REMOTE
```

**Write the passphrase down and keep it offline** (printed, in the firm's safe). Without it, the backups
cannot be opened by anyone, including you.

Off-site copy: create a Backblaze B2 account and a private bucket, e.g. `vdl-dashboard-backups`, with
an application key limited to that bucket. Then run `rclone config`, add a remote called `b2` of type
Backblaze B2 with that key, and set `RCLONE_REMOTE=b2:vdl-dashboard-backups`. Turn on the bucket's
lifecycle rule "keep only the last version" and set it to delete files older than 90 days.

Test it, then schedule it:

```bash
vdl-backup                                  # should print "Backup written: ..."
rclone ls b2:vdl-dashboard-backups          # the file should be there
cp /opt/vdl-dashboard/docs/law-firm/hosting/vdl-backup.cron /etc/cron.d/vdl-backup
```

**Test a restore** once before go-live, and then every three months. The safest way is on a second,
temporary server built with sections 4 and 7, so the live one is untouched:

```bash
rclone copy b2:vdl-dashboard-backups/vdl-2026-12-01_0130.tar.gpg /var/backups/vdl-dashboard/
vdl-restore /var/backups/vdl-dashboard/vdl-2026-12-01_0130.tar.gpg
```

The restore also needs the same `SECRET_KEY_BASE` in `/etc/vdl-dashboard.env`, or saved secrets such
as 2FA devices will not work.

## 8. Security

### Firewall and logins

```bash
ufw allow OpenSSH && ufw allow 'Nginx Full' && ufw --force enable
systemctl enable --now fail2ban             # blocks repeated SSH password guesses
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload ssh
dpkg-reconfigure -plow unattended-upgrades  # answer Yes: Ubuntu security fixes install automatically
```

### Two-factor authentication

`OPENPROJECT_2FA_ENFORCED=true` in `/etc/vdl-dashboard.env` makes every user set up 2FA on their next
sign-in, and admins cannot switch it off from the web page. Users scan a QR code with Google
Authenticator, Microsoft Authenticator or similar, or use a security key (WebAuthn). Each user should
save their backup codes when shown.

If someone loses their phone, an admin removes their old 2FA device from the user's page under
**Administration > Users**, and they set up a new one at the next sign-in.

### Inside the dashboard

1. Change the `admin` password at first sign-in and give the admin account to one or two partners only.
2. Under **Administration > Authentication > Settings**, set **Self-registration** to **disabled**, so only invited staff get accounts.
3. Delete the demo projects.
4. Invite staff by email under **Administration > Users > + User**.

## 9. Updates

To bring the server up to the latest `dev` branch (new features from this repository, plus
OpenProject fixes once they are merged into the fork):

```bash
install -m 750 /opt/vdl-dashboard/docs/law-firm/hosting/vdl-update.sh /usr/local/sbin/vdl-update
vdl-update
```

The script takes a backup, pulls the code, rebuilds, migrates the database and restarts. Run it in the
evening, since the dashboard is down for the 15 to 30 minutes the rebuild takes. If an update goes
wrong, restore the backup it made (section 7).

Ubuntu security updates install by themselves (section 8). Reboot once a month, or when
`/var/run/reboot-required` exists: `reboot`.

Health checks worth bookmarking:

| What | Command |
|---|---|
| Is it running? | `systemctl status vdl-dashboard-web vdl-dashboard-worker` |
| Recent errors | `journalctl -u vdl-dashboard-web --since today` |
| Last backup | `tail -5 /var/log/vdl-backup.log` |
| Disk space | `df -h /` |

For a free outside alert when the site goes down, add `https://YOUR.REAL.ADDRESS/health_check`
to UptimeRobot (free plan) with Van's email.

## 10. Connecting the desktop app

Once `https://YOUR.REAL.ADDRESS` opens in a browser:

1. In GitHub, set the repository variable `DASHBOARD_SERVER_URL` to `https://YOUR.REAL.ADDRESS`
   (Settings > Secrets and variables > Actions > Variables), and run the **Desktop app (Windows
   installer)** workflow. The new installer suggests the right address.
2. Install it on each PC. Staff click **Save and open** and sign in.
3. PCs that already have the app: **File > Server settings…** (Ctrl+,), enter the new address, save.

The app only accepts `https://` addresses for online servers, which is why section 5 comes first.

## 11. Moving the data from Van's PC

If the firm has already entered real matters on the WSL copy, move them instead of starting fresh.
In WSL on Van's PC:

```bash
pg_dump --format=custom openproject_dev > ~/vdl-move.dump    # use the database name in config/database.yml
tar -C ~/vdl-dashboard -czf ~/vdl-files.tar.gz files         # the attachments folder, if any
scp ~/vdl-move.dump ~/vdl-files.tar.gz root@<server-ip>:/root/
```

On the server, before section 4.6 (or with the services stopped):

```bash
sudo -u postgres dropdb vdl_dashboard && sudo -u postgres createdb -O vdl vdl_dashboard
sudo -u postgres pg_restore --no-owner --role=vdl -d vdl_dashboard /root/vdl-move.dump
tar -C /var/lib/vdl-dashboard -xzf /root/vdl-files.tar.gz --strip-components=1 && chown -R vdl:vdl /var/lib/vdl-dashboard
su - vdl -c 'cd /opt/vdl-dashboard && set -a && . /etc/vdl-dashboard.env && set +a && bundle exec rails db:migrate'
```

Passwords and 2FA set up on the PC stay valid only if the PC used the same `SECRET_KEY_BASE`. If not,
users reset their passwords by email after the move.

## 12. Go-live checklist

- [ ] `https://` address opens with a padlock
- [ ] Test email received
- [ ] `admin` password changed, self-registration off, demo projects deleted
- [ ] 2FA set up by every user
- [ ] First backup is off-site, and a restore was tested
- [ ] Backup passphrase and `SECRET_KEY_BASE` stored offline
- [ ] Desktop app installed on every PC and pointing at the new address
- [ ] Data Protection Officer signed off
