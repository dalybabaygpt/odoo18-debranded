# ⚙️ Odoo CE 18 – Full Automated Installer (Debranded, SSL, Real-Time Ready)

This repo provides a **3-script setup** to launch a production-ready Odoo CE 18 on any Ubuntu 22.04+ or 24.04 server.

All scripts are fully debranded, use your custom modules, support Cloudflare DNS, enable Let's Encrypt SSL, and fix real-time connection issues with WebSocket (`/longpolling`).

---

## 📜 Scripts Overview

### 1️⃣ `install_ip18.sh` — Base Odoo CE 18 Installer

**Use case:** When you want to install Odoo CE 18 using the **server IP only** (no domain yet).

**Features:**
- Installs Odoo 18 with Python venv
- PostgreSQL setup
- Custom addons folder support
- Debranded from start
- Systemd service included

**Run it:**
```bash
bash <(curl -s https://raw.githubusercontent.com/dalybabaygpt/ERP18-debranded/main/scripts/install_ip18.sh)
```

---

### 2️⃣ `create_SSL.sh` — Add HTTPS + Real-Time Fix

**Use case:** When your domain is ready and pointing to the server. This script configures:
- NGINX reverse proxy
- Let's Encrypt SSL with Certbot
- Cloudflare IP whitelisting
- WebSocket `/longpolling` for real-time
- Odoo config fix (`proxy_mode`, `workers`, `gevent_port`)

**Prompts:**
- Your domain (e.g., `erp.example.com`)
- Your email (for SSL cert)

**Run it:**
```bash
bash <(curl -s https://raw.githubusercontent.com/dalybabaygpt/ERP18-debranded/main/scripts/create_SSL.sh)
```



🔄 Daily Auto-Sync for Custom Addons
To ensure all your Odoo databases always have the latest custom modules, you can run Script2 to automatically pull updates from this repository every day at 4:00 AM and restart Odoo.

✅ How to Enable
After installing Odoo using Script1, simply run:

bash
Copy
Edit

bash <(curl -s https://raw.githubusercontent.com/dalybabaygpt/ERP18-debranded/main/scripts/Script2.sh)

This will:

Clone (or pull) the latest custom_addons from this repo

Create a sync script at /opt/odoo/git_sync.sh

Schedule it to run daily at 4:00 AM using cron

Restart the Odoo service automatically

📌 Notes
Works with both new and existing Odoo installations

Safe to run multiple times (won’t duplicate cron jobs)

Logs are saved to /var/log/odoo_git_sync.log





---

### 3️⃣ `install_full.sh` — One-Click Install for Domain-Based Setup

**Use case:** When starting from scratch with a domain already ready (DNS set).

**Combines:**
- Odoo CE 18 base install (`install_ip18.sh`)
- SSL + Real-time config (`create_SSL.sh`)

**Prompts:**
- Your domain
- Your email

**Run it:**
```bash
bash <(curl -s https://raw.githubusercontent.com/dalybabaygpt/ERP18-debranded/main/scripts/install_full.sh)
```

---

## ✅ Requirements

- Ubuntu 22.04 or 24.04 (fresh VPS)
- Root SSH access
- Domain pointing to the server IP (if using Script 2 or 3)
- Port 80/443 open
- Cloudflare DNS (recommended)

---

## 🛠️ What's Included

| Feature                          | Supported? |
|----------------------------------|------------|
| Odoo 18 CE (latest build)        | ✅         |
| Python virtualenv                | ✅         |
| Custom addons loader             | ✅         |
| WebSocket real-time support      | ✅         |
| Cloudflare WebSocket passthrough | ✅         |
| SSL via Let's Encrypt            | ✅         |
| NGINX reverse proxy              | ✅         |
| Longpolling & gevent fix         | ✅         |
| Debranded install                | ✅         |

---

## 🧠 Tips & Troubleshooting
Remove reloading Odooai:
go to views then web.webclient_bootstrap the add this to the second line: 
    <t t-set="title">ERP</t>
    
- Check `https://yourdomain.com/websocket` or `/longpolling` in browser dev tools to confirm real-time is working.
- Run `ss -tuln | grep 8072` to verify gevent is active.
- If NGINX fails, run:
```bash
nginx -t
journalctl -xeu nginx.service
```
- For SSL issues, make sure DNS is pointed correctly, and rerun:
```bash
certbot --nginx -d yourdomain.com --non-interactive --agree-tos -m you@example.com
```

---

## 📂 Directory Structure

```
scripts/
├── install_ip18.sh        # Script 1
├── create_SSL.sh          # Script 2
└── install_full.sh        # Script 3 (Combo)
custom_addons/
└── your modules here...
```

---

## 🤝 Contribute

You’re welcome to fork, adapt, or report issues. Pull requests are reviewed quickly.

---

## 🚀 Author

Created and maintained by [@dalybabaygpt](https://github.com/dalybabaygpt) for high-speed ERP deployment & automation.

---

## 📘 License

MIT License – Free for commercial and personal use.




NOTES: Remove reloading Odooai:
go to views then web.webclient_bootstrap the add this to the second line: 
    <t t-set="title">ERP</t>

So it looks like this:
 <t t-name="web.webclient_bootstrap">
    <t t-set="title">ERP</t>

Or 
        <title><t t-raw="title"/></title>

