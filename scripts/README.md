# 📦 SmartERP Scripts

This folder contains deployment scripts for setting up and configuring SmartERP (Odoo 18 CE).

Step	Command from SSH terminal:
1	apt update && apt install -y git
2	git clone https://github.com/dalybabaygpt/odoo18-debranded.git
3	cd odoo18-debranded
4	bash scripts/full_auto_deploy.sh

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
