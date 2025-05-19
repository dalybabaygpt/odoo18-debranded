
from odoo import models

class FixUrl(models.Model):
    _inherit = "ir.config_parameter"

    def fix_url_parameters(self):
        if self.get_param('web.base.sorturl') != 'erp':
            self.set_param('web.base.sorturl', 'erp')
        base_url = self.get_param('web.base.url')
        if '/odoo' in base_url:
            self.set_param('web.base.url', base_url.replace('/odoo', ''))
