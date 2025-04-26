# 📦 SmartERP Scripts

This folder contains deployment scripts for setting up and configuring SmartERP (Odoo 18 CE).

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
