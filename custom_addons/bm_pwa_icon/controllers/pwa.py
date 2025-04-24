# -*- coding: utf-8 -*-
# See LICENSE file for full licensing details.
# See COPYRIGHT file for full copyright details.
# Developed by Bizmate - Unbox Solutions Co., Ltd.

import json
from odoo import http
from odoo.http import request
from odoo.exceptions import AccessError
import mimetypes


class PwaMain(http.Controller):

    def _get_shortcuts(self):
        module_names = ['mail', 'crm', 'project', 'project_todo']
        try:
            module_ids = request.env['ir.module.module'].search([('state', '=', 'installed'), ('name', 'in', module_names)]) \
                                                        .sorted(key=lambda r: module_names.index(r["name"]))
        except AccessError:
            return []
        menu_roots = request.env['ir.ui.menu'].get_user_roots()
        datas = request.env['ir.model.data'].sudo().search([('model', '=', 'ir.ui.menu'),
                                                            ('res_id', 'in', menu_roots.ids),
                                                            ('module', 'in', module_names)])
        shortcuts = []
        for module in module_ids:
            data = datas.filtered(lambda res: res.module == module.name)
            if data:
                shortcuts.append({
                    'name': module.display_name,
                    'url': '/odoo?menu_id=%s' % data.mapped('res_id')[0],
                    'description': module.display_name,
                    'icons': [{
                        'sizes': '100x100',
                        'src': module.icon,
                        'type': mimetypes.guess_type(module.icon)[0] or 'image/png'
                    }]
                })
        return shortcuts

    @http.route('/bm_pwa_icon/<int:company_id>/manifest', type='http', auth="public")
    def manifest(self, company_id=None):
        
        company = request.env['res.company'].browse(company_id)
        manifest = {
            'name': company.pwa_app_name if company else 'Odoo',
            'scope': '/odoo',
            'start_url': '/odoo',
            'display': 'standalone',
            'background_color': '#1B1B1B',
            'theme_color': '#1B1B1B',
            'prefer_related_applications': False,
        }
        icon_list = []
        icon_sizes = ['192x192', '512x512']
        for icon_size in icon_sizes:
            icon_list.append({
                'src': "/web/image/res.company/%s/web_app_icon_%s_pwa/%s" % (company_id, icon_size.split('x')[0], icon_size),
                'sizes': icon_size,
                'type': 'image/png',
            })
        manifest['icons'] = icon_list
        manifest['shortcuts'] = self._get_shortcuts()
        return request.make_json_response(manifest, {
            'Content-Type': 'application/manifest+json'
        })