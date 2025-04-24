# -*- coding: utf-8 -*-
# See LICENSE file for full licensing details.
# See COPYRIGHT file for full copyright details.
# Developed by Bizmate - Unbox Solutions Co., Ltd.

from odoo import fields, models


class ResCompany(models.Model):
    _inherit = 'res.company'

    pwa_app_name = fields.Char('PWA App Name')
    web_app_icon_192_pwa = fields.Binary('Image 192px')
    web_app_icon_512_pwa = fields.Binary('Image 512px')
