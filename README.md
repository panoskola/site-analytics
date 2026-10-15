# site-analytics

Self-hosted, cookieless visitor analytics for my personal site
[panoskola.github.io](https://panoskola.github.io), running on a free cloud VM.

The site itself stays on GitHub Pages. This repository is the infrastructure behind the
visitor dashboard: Docker Compose, a reverse proxy with automatic HTTPS, the database,
backups and the runbook to rebuild everything from scratch.

## Architecture

```
Visitor ──► panoskola.github.io (GitHub Pages)
               │  <script src="https://panoskola-stats.duckdns.org/script.js">
               ▼
        panoskola-stats.duckdns.org  (free DuckDNS hostname → VM public IP)
               │  :443
        ┌──────┴───────────────────────── Oracle Cloud VM (Always Free, Ubuntu 24.04) ─┐
        │  Caddy  ── automatic Let's Encrypt certificate, HTTPS, security headers        │
        │    └──► Umami :3000  ── dashboard + tracking API (not exposed directly)        │
        │           └──► PostgreSQL 16  ── data volume, daily pg_dump backups           │
        └──────────────────────────────────────────────────────────────────────────────┘
```

| Component | Why |
|---|---|
| **Umami** | Open-source, privacy-friendly analytics. No cookies, no personal data, GDPR-friendly. |
| **Caddy** | Reverse proxy that requests and renews TLS certificates on its own. |
| **PostgreSQL** | Umami's database. Only reachable on the internal Docker network. |
| **DuckDNS** | Free hostname, so no domain purchase is needed. Required for a valid HTTPS certificate. |

Only ports 22 (SSH, key-only), 80 and 443 are open. Port 80 is used only for the
certificate challenge and redirects to HTTPS.

## Runbook

### 1. VM (Oracle Cloud Always Free)

1. Create an Oracle Cloud account. The home region cannot be changed later, so pick one close
   to the visitors (e.g. Frankfurt or Amsterdam).
2. **Compute → Instances → Create instance**
   - Image: **Canonical Ubuntu 24.04**
   - Shape: **VM.Standard.A1.Flex (Ampere)**, **1 OCPU / 6 GB** — inside the Always Free
     limit of 2 OCPU / 12 GB across the account.
   - Networking: create a VCN with a public subnet, **assign a public IPv4 address**.
   - SSH keys: upload your public key (`ssh-keygen -t ed25519` if you don't have one).
3. **Networking → VCN → Security Lists → Default → Add Ingress Rules**
   - Source `0.0.0.0/0`, TCP, destination port **80**
   - Source `0.0.0.0/0`, TCP, destination port **443**

### 2. Free hostname (DuckDNS)

1. Sign in at [duckdns.org](https://www.duckdns.org) (GitHub login works).
2. Add a subdomain, e.g. `panoskola-stats`, and set its IP to the VM's public IP.
3. Copy the token shown at the top of the page.

### 3. Server setup

```bash
ssh ubuntu@<VM_PUBLIC_IP>

sudo apt update && sudo apt -y upgrade
sudo apt -y install git unattended-upgrades
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && exit        # log out and back in
```

```bash
ssh ubuntu@<VM_PUBLIC_IP>
git clone https://github.com/panoskola/site-analytics.git
cd site-analytics
./scripts/open-firewall.sh                   # Oracle images block 80/443 in iptables
```

### 4. Configure and start

```bash
cp .env.example .env
openssl rand -hex 32                          # run twice: POSTGRES_PASSWORD, APP_SECRET
nano .env                                     # fill UMAMI_DOMAIN, secrets, DuckDNS token
docker compose up -d
docker compose logs -f caddy                  # wait for "certificate obtained successfully"
```

### 5. Dashboard

1. Open `https://panoskola-stats.duckdns.org`
2. Log in with the default `admin` / `umami` and **change the password immediately**
   (Profile → Change password).
3. **Settings → Websites → Add website** — name `Personal site`, domain `panoskola.github.io`.
4. Open the website's **Tracking code** and copy it.

### 6. Connect the site

Add the tracking code inside `<head>` of `index.html` in the
[site repository](https://github.com/panoskola/panoskola.github.io):

```html
<script defer src="https://panoskola-stats.duckdns.org/script.js"
        data-website-id="<WEBSITE_ID>"
        data-domains="panoskola.github.io"></script>
```

`data-domains` makes sure only visits on the real site are counted, not local copies.

To exclude my own visits, run once in the browser console on the site:

```js
localStorage.setItem('umami.disabled', 1)
```

### 7. Maintenance

```bash
crontab -e
# 15 3 * * *   /home/ubuntu/site-analytics/scripts/backup.sh
# */30 * * * * /home/ubuntu/site-analytics/scripts/duckdns-update.sh
```

Update to a new Umami release:

```bash
cd ~/site-analytics && docker compose pull && docker compose up -d
```

Restore a backup:

```bash
gunzip -c backups/umami-YYYY-MM-DD.sql.gz | docker compose exec -T db psql -U umami umami
```

## Troubleshooting

| Symptom | Check |
|---|---|
| Browser can't reach the hostname | `nslookup panoskola-stats.duckdns.org` returns the VM IP? OCI Security List has 80/443? `sudo iptables -L INPUT -n` shows ACCEPT for 80/443 before the REJECT rule? |
| Caddy can't get a certificate | Port 80 must be reachable from the internet. `docker compose logs caddy` |
| Dashboard loads, no visits counted | Tracking code in `<head>`? `data-website-id` correct? Ad blockers block analytics scripts — test in a clean browser profile. |
| Umami restarts in a loop | `docker compose logs umami` — usually a wrong `DATABASE_URL` or password in `.env`. |

## Security notes

- SSH key authentication only; no passwords.
- Secrets live in `.env`, which is git-ignored.
- PostgreSQL and Umami are not published to the host; only Caddy listens on 80/443.
- Unattended security upgrades enabled on the host.
