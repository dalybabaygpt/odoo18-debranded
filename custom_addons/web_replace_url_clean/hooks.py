
def run_post_install_hook(cr, registry):
    from odoo.api import Environment
    env = Environment(cr, SUPERUSER_ID, {})
    env['ir.config_parameter'].fix_url_parameters()
