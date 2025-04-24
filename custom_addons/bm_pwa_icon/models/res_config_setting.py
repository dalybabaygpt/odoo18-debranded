# -*- coding: utf-8 -*-
# See LICENSE file for full licensing details.
# See COPYRIGHT file for full copyright details.
# Developed by Bizmate - Unbox Solutions Co., Ltd.

from odoo.modules.module import get_resource_path
from odoo import api, http, fields, models, tools, _
from odoo.tools.misc import file_path
from odoo.http import request
import base64

class ResConfig(models.TransientModel):
    _inherit = 'res.config.settings'

    pwa_app_name = fields.Char('PWA App Name', related='company_id.pwa_app_name', readonly=False)
    web_app_icon_192_pwa = fields.Binary('Image 192px', related='company_id.web_app_icon_192_pwa', readonly=False)
    web_app_icon_512_pwa = fields.Binary('Image 512px', related='company_id.web_app_icon_512_pwa', readonly=False)