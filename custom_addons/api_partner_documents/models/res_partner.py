# -*- coding: utf-8 -*-
# Copyright (c) 2025-Present API SERVICE S.A.C. (<https://www.apiservicesac.com/>)
from odoo import api, fields, models, _


class PartnerDocuments(models.Model):
    """This class Inherits the res.partner model to add document count field"""
    _inherit = 'res.partner'

    partner_document_ids = fields.One2many(
        string="Documents",
        comodel_name='partner.document',
        inverse_name='res_id',
        domain=lambda self: [('res_model', '=', self._name)])
    partner_document_count = fields.Integer(
        string="Documents Count", compute='_compute_partner_document_count')
    
    def _compute_partner_document_count(self):
        for partner in self:
            partner.partner_document_count = partner.env['partner.document'].search_count([
                ('res_model', '=', 'res.partner'),
                ('res_id', '=', partner.id),
            ])
    
    def action_open_documents(self):
        self.ensure_one()
        return {
            'name': _('Documents'),
            'type': 'ir.actions.act_window',
            'res_model': 'partner.document',
            'view_mode': 'kanban,tree,form',
            'context': {
                'default_res_model': self._name,
                'default_res_id': self.id,
                'default_company_id': self.company_id.id,
            },
            'domain': [('res_model', '=', 'res.partner'), ('res_id', '=', self.id)],
            'target': 'current',
            'help': """
                <p class="o_view_nocontent_smiling_face">
                    %s
                </p>
                <p>
                    %s
                    <br/>
                    %s
                </p>
                <p>
                    <a class="oe_link" href="https://www.odoo.com/documentation/17.0/_downloads/5f0840ed187116c425fdac2ab4b592e1/pdfquotebuilderexamples.zip">
                    %s
                    </a>
                </p>
            """ % (
                _("Upload files to your partner"),
                _("Use this feature to store any files you would like to share with your customers"),
                _("(e.g: partner description, ebook, legal notice, ...)."),
                _("Download examples")
            )
        }
