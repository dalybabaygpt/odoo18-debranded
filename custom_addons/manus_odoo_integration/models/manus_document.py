# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
import base64
import logging

_logger = logging.getLogger(__name__)

class ManusDocument(models.Model):
    _name = 'manus.document'
    _description = 'Manus Document Processing'
    _rec_name = 'name'
    
    name = fields.Char(string='Name', required=True)
    document_file = fields.Binary(string='Document File', attachment=True)
    document_filename = fields.Char(string='Document Filename')
    document_type = fields.Selection([
        ('invoice', 'Invoice'),
        ('receipt', 'Receipt'),
        ('contract', 'Contract'),
        ('resume', 'Resume'),
        ('id_card', 'ID Card'),
        ('other', 'Other'),
    ], string='Document Type', default='other', required=True)
    
    state = fields.Selection([
        ('draft', 'Draft'),
        ('processing', 'Processing'),
        ('processed', 'Processed'),
        ('failed', 'Failed'),
    ], string='Status', default='draft')
    
    extracted_data = fields.Text(string='Extracted Data (JSON)')
    processing_result = fields.Text(string='Processing Result')
    error_message = fields.Text(string='Error Message')
    
    # Relationships
    partner_id = fields.Many2one('res.partner', string='Related Partner')
    user_id = fields.Many2one('res.users', string='Responsible', default=lambda self: self.env.user)
    company_id = fields.Many2one('res.company', string='Company', default=lambda self: self.env.company)
    
    def action_process_document(self):
        """Process the document using Manus AI"""
        self.ensure_one()
        
        if not self.document_file:
            self.write({
                'state': 'failed',
                'error_message': 'No document file uploaded'
            })
            return False
        
        # Get active connector
        connector = self.env['manus.connector'].get_active_connector()
        if not connector:
            self.write({
                'state': 'failed',
                'error_message': 'No active Manus connector found'
            })
            return False
        
        # Check if document processing is enabled
        if not connector.enable_document_processing:
            self.write({
                'state': 'failed',
                'error_message': 'Document processing is not enabled in Manus settings'
            })
            return False
        
        try:
            # Set to processing state
            self.write({'state': 'processing'})
            
            # Prepare document data
            document_data = base64.b64encode(base64.b64decode(self.document_file)).decode('utf-8')
            
            # Call Manus API
            payload = {
                'document': document_data,
                'document_type': self.document_type,
                'filename': self.document_filename,
            }
            
            response = connector.call_manus_api('document/process', method='POST', data=payload)
            
            if response:
                self.write({
                    'state': 'processed',
                    'extracted_data': response.get('data'),
                    'processing_result': response.get('result'),
                    'error_message': False
                })
                return True
            else:
                self.write({
                    'state': 'failed',
                    'error_message': 'Failed to process document with Manus API'
                })
                return False
                
        except Exception as e:
            self.write({
                'state': 'failed',
                'error_message': str(e)
            })
            _logger.exception(f"Error processing document with Manus: {str(e)}")
            return False
    
    def action_reset_to_draft(self):
        """Reset document to draft state"""
        self.write({
            'state': 'draft',
            'extracted_data': False,
            'processing_result': False,
            'error_message': False
        })
        return True
