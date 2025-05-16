import subprocess
import os
import logging
from odoo import models

_logger = logging.getLogger(__name__)

GIT_REPO = "https://github.com/dalybabaygpt/ERP18-debranded"
ADDONS_PATH = "/mnt/extra-addons/custom_addons"

class CustomAddonsSync(models.Model):
    _name = "custom.addons.sync"
    _description = "Sync Custom Addons from GitHub"

    def run_sync(self):
        try:
            if not os.path.exists(ADDONS_PATH):
                _logger.info("Cloning repo for the first time.")
                subprocess.run(["git", "clone", GIT_REPO, "/mnt/extra-addons"], check=True)
            else:
                _logger.info("Pulling latest changes from Git repo.")
                subprocess.run(["git", "-C", "/mnt/extra-addons", "pull"], check=True)
        except subprocess.CalledProcessError as e:
            _logger.error(f"Git operation failed: {e}")
            return

        # List folders in custom_addons and try to upgrade if installed
        for module in os.listdir(ADDONS_PATH):
            full_path = os.path.join(ADDONS_PATH, module)
            if os.path.isdir(full_path):
                module_rec = self.env['ir.module.module'].search([('name', '=', module)])
                if module_rec.state == 'installed':
                    _logger.info(f"Upgrading module: {module}")
                    module_rec.button_upgrade()