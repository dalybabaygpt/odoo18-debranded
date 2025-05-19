from odoo import api, SUPERUSER_ID

def post_init_hook(cr, registry):
    env = api.Environment(cr, SUPERUSER_ID, {})
    env['ir.config_parameter'].set_param('web.base.sorturl', 'erp')
    env['ir.config_parameter'].set_param('web.base.url', 'http://localhost:8069')
