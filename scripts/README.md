# 📦 SmartERP Scripts

This folder contains deployment scripts for setting up and configuring SmartERP (Odoo 18 CE).

So now for a fresh Ubuntu server, you only have to:
👉 Connect by SSH
👉 Copy this one line:

apt update && apt install -y git && git clone https://dalybabaygpt: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@github.com/dalybabaygpt/odoo18-debranded.git && cd odoo18-debranded && bash scripts/install_full_with_domain.sh

👉 Press Enter
👉 DONE ✅

True one-button deployment boss.

## ⚙️ Deployment Scripts

| Script | Description |
|:---|:---|
| [install_smarterp.sh](install_smarterp.sh) | Full SmartERP installation: Odoo 18 CE + PostgreSQL + virtualenv + custom modules + systemd service |
| [create_odoo_nginx.sh](create_odoo_nginx.sh) | Bulletproof Nginx reverse proxy with SSL (Let's Encrypt), WebSocket, and Longpolling real-time support |
| [full_auto_deploy.sh](full_auto_deploy.sh) | Combined script to install SmartERP and (optionally) configure SSL and Nginx automatically |

---

## 🚀 Quick Usage

1. Install SmartERP (Odoo 18 CE + PostgreSQL + system setup):
   ```bash
   bash scripts/install_smarterp.sh
