# Putting the VDL Dashboard online

This guide moves the dashboard from Van's PC (WSL, `http://localhost:3000`) to a server on the
internet, so every PC in the firm can use it through the desktop app. Nothing here has been
bought or set up yet. Follow it top to bottom when you are ready.

Status: **draft**. Sections marked *TODO* are still being written.

## 1. What you will end up with

```
 Office PCs (desktop app) ──HTTPS──▶ dashboard.vdl-law.ph ──▶ nginx ──▶ VDL Dashboard (Puma)
                                                                  │
                                                     PostgreSQL + attachments folder
                                                                  │
                                               encrypted nightly backup ──▶ off-site storage
```

## 2. Recommended server

| | Recommended | Why |
|---|---|---|
| Region | **Singapore** | About 30 to 50 ms from Manila. Tokyo is the fallback. |
| Size | **4 GB RAM, 2 vCPU, 80 GB disk** to start; 8 GB if more than ~25 users | OpenProject needs about 4 GB to run comfortably. |
| OS | **Ubuntu 24.04 LTS** | Supported until 2029, and what this guide is written for. |

### Providers and monthly cost (prices as listed late 2026, check before buying; PHP at ₱58 = US$1)

| Provider | Plan | USD/month | PHP/month | Notes |
|---|---|---|---|---|
| DigitalOcean | Basic Droplet 4 GB / 2 vCPU, Singapore | ~$24 | ~₱1,400 | Easiest panel. Backups add 20% (~₱280). |
| AWS Lightsail | 4 GB / 2 vCPU, Singapore | ~$24 | ~₱1,400 | Good if the firm will use other AWS services. |
| Hetzner | CPX31 4 vCPU / 8 GB, Singapore | ~$20 | ~₱1,150 | Cheapest for the RAM, less hand-holding. |
| Vultr | 4 GB High Performance, Singapore | ~$24 | ~₱1,400 | Similar to DigitalOcean. |

Other running costs:

| Item | USD/month | PHP/month |
|---|---|---|
| Domain (e.g. `vdl-law.ph` ≈ ₱2,000/yr, or a `.com` ≈ ₱700/yr) | ~$1 to $3 | ~₱60 to ₱170 |
| Off-site backup storage (Backblaze B2 or Wasabi, ~50 GB) | ~$0.50 to $7 | ~₱30 to ₱400 |
| Email sending (Brevo free tier 300/day, or Google Workspace the firm already pays for) | $0 | ₱0 |
| HTTPS certificate (Let's Encrypt) | $0 | ₱0 |
| **Total** | **~$25 to $35** | **~₱1,500 to ₱2,000** |

**Recommendation:** DigitalOcean, Singapore, 4 GB Droplet, with the provider's weekly backups turned on
*in addition to* our own nightly encrypted backups (section 7).

## 3. Before you start

1. Buy the domain and decide the address, e.g. `dashboard.vdl-law.ph`.
2. Create the server (Ubuntu 24.04, Singapore). Choose **SSH key** login, not a password.
3. In the domain's DNS settings add an **A record**: `dashboard` → the server's IP address.
4. Have the firm's email (SMTP) details ready (section 6).

## 4. Production install

The fork has its own code (legal seed data, PH holidays, deadline digest, branding), so it is installed
from this repository rather than from the stock OpenProject package. Log in with `ssh root@<server-ip>`.

### 4.1 Base system

```bash
timedatectl set-timezone Asia/Manila
apt update && apt -y upgrade
apt -y install git curl build-essential libssl-dev libyaml-dev libffi-dev zlib1g-dev \
  libpq-dev postgresql nginx certbot python3-certbot-nginx gnupg rclone ufw fail2ban unattended-upgrades
adduser --disabled-password --gecos "" vdl
mkdir -p /opt/vdl-dashboard /var/lib/vdl-dashboard/files
chown vdl:vdl /opt/vdl-dashboard /var/lib/vdl-dashboard/files
```

### 4.2 Database

```bash
sudo -u postgres createuser vdl
sudo -u postgres createdb -O vdl vdl_dashboard
```

### 4.3 Ruby 4.0.10 and Node 24 (as the `vdl` user)

```bash
su - vdl
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc && source ~/.bashrc
rbenv install 4.0.10 && rbenv global 4.0.10
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -   # or run this part as root
sudo apt -y install nodejs
```

### 4.4 Get the code and build it

```bash
git clone --branch dev https://github.com/elijah05050602/vdl-dashboard.git /opt/vdl-dashboard
cd /opt/vdl-dashboard
bundle config set --local deployment true
bundle config set --local without 'development test'
bundle install
npm ci
```

As root, copy `docs/law-firm/hosting/vdl-dashboard.env.example` to `/etc/vdl-dashboard.env`, fill it in
(`openssl rand -hex 64` for `SECRET_KEY_BASE`), then `chown vdl /etc/vdl-dashboard.env && chmod 600 /etc/vdl-dashboard.env`.

Back as `vdl`:

```bash
set -a; source /etc/vdl-dashboard.env; set +a
bundle exec rails assets:precompile
bundle exec rails db:migrate db:seed
bundle exec rails law_firm:ph_holidays
```

### 4.5 Run it as a service (as root)

```bash
cp /opt/vdl-dashboard/docs/law-firm/hosting/vdl-dashboard-{web,worker}.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now vdl-dashboard-web vdl-dashboard-worker
systemctl status vdl-dashboard-web
```

Log in with `admin` / `admin` (or the seed admin), change the password at once, and delete the demo projects.

## 5. HTTPS with Let's Encrypt

Uses `docs/law-firm/hosting/nginx-vdl-dashboard.conf`. *TODO: full steps.*

## 6. Email (SMTP)

*TODO.*

## 7. Encrypted daily backups

Uses `docs/law-firm/hosting/vdl-backup.sh`. *TODO: full steps and restore test.*

## 8. Security: 2FA, firewall, logins

*TODO.*

## 9. Updates

*TODO.*

## 10. Connecting the desktop app

Point the desktop app (PR 4) at `https://dashboard.vdl-law.ph` instead of `http://localhost:3000`.
*TODO: exact setting.*
