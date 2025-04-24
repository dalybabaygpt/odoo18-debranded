# -*- coding: utf-8 -*-
# Copyright (c) 2025-Present API SERVICE S.A.C. (<https://www.apiservicesac.com/>)
import json
import logging

from odoo import _
from odoo.http import request, route, Controller

logger = logging.getLogger(__name__)


class PartnerDocumentController(Controller):

    @route('/partner/document/upload', type='http', methods=['POST'], auth='user')
    def upload_document(self, ufile, res_model, res_id):
        if res_model not in ('res.partner'):
            return

        record = request.env[res_model].browse(int(res_id)).exists()

        if not record or not record.check_access_rights('write'):
            return

        files = request.httprequest.files.getlist('ufile')
        result = {'success': _("All files uploaded")}
        for ufile in files:
            try:
                mimetype = ufile.content_type
                request.env['partner.document'].create({
                    'name': ufile.filename,
                    'res_model': record._name,
                    'res_id': record.id,
                    'company_id': record.company_id.id,
                    'mimetype': mimetype,
                    'raw': ufile.read(),
                })
            except Exception as e:
                logger.exception("Failed to upload document %s", ufile.filename)
                result = {'error': str(e)}

        return json.dumps(result)
