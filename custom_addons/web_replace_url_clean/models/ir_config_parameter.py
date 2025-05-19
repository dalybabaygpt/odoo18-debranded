
from odoo import models, api

class ConfigParamPatch(models.Model):
    _inherit = 'ir.config_parameter'

    @api.model
    def fix_url_parameters(self):
        self.set_param("web.base.sorturl", "erp")
        base_url = self.get_param("web.base.url", "")
        if "/odoo" in base_url:
            self.set_param("web.base.url", base_url.replace("/odoo", ""))
        if not base_url:
            self.set_param("web.base.url", "http://localhost:8069")
