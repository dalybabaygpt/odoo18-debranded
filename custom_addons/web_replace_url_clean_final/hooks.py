
def run_post_install_hook(cr, registry):
    from odoo.api import Environment
    env = Environment(cr, SUPERUSER_ID, {})
    env['ir.config_parameter'].sudo().set_param('web.base.sorturl', 'erp')
    base_url = env['ir.config_parameter'].sudo().get_param('web.base.url')
    if '/odoo' in base_url:
        new_url = base_url.replace('/odoo', '')
        env['ir.config_parameter'].sudo().set_param('web.base.url', new_url)
