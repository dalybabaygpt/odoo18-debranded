# -*- coding: utf-8 -*-
# Copyright (c) 2025-Present API SERVICE S.A.C. (<https://www.apiservicesac.com/>)
from odoo import api, models


class IrAttachment(models.Model):
    _inherit = 'ir.attachment'

    @api.model_create_multi
    def create(self, vals_list):
        """Create partner.document for attachments added in partners chatters"""
        attachments = super().create(vals_list)
        if not self.env.context.get('disable_partner_documents_creation'):
            partner_attachments = attachments.filtered(
                lambda attachment:
                    attachment.res_model in ('res.partner')
                    and not attachment.res_field
            )
            if partner_attachments:
                self.env['partner.document'].sudo().create(
                    {
                        'ir_attachment_id': attachment.id
                    } for attachment in partner_attachments
                )
        return attachments
