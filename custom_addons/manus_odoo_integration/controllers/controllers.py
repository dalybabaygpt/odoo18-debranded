# -*- coding: utf-8 -*-
from odoo import http
from odoo.http import request
import json
import logging

_logger = logging.getLogger(__name__)

class ManusController(http.Controller):
    @http.route('/manus/webhook', type='json', auth='public', csrf=False)
    def manus_webhook(self, **post):
        """Webhook endpoint for Manus API callbacks"""
        try:
            data = request.jsonrequest
            _logger.info(f"Received webhook from Manus: {data}")
            
            # Verify webhook signature if provided
            signature = request.httprequest.headers.get('X-Manus-Signature')
            if signature:
                # TODO: Implement signature verification
                pass
            
            # Process webhook based on event type
            event_type = data.get('event_type')
            if not event_type:
                return {'status': 'error', 'message': 'Missing event_type'}
            
            if event_type == 'document_processed':
                return self._handle_document_processed(data)
            elif event_type == 'analysis_completed':
                return self._handle_analysis_completed(data)
            else:
                return {'status': 'error', 'message': f'Unknown event type: {event_type}'}
                
        except Exception as e:
            _logger.exception(f"Error processing Manus webhook: {str(e)}")
            return {'status': 'error', 'message': str(e)}
    
    def _handle_document_processed(self, data):
        """Handle document_processed webhook event"""
        document_id = data.get('document_id')
        if not document_id:
            return {'status': 'error', 'message': 'Missing document_id'}
        
        document = request.env['manus.document'].sudo().search([('id', '=', int(document_id))], limit=1)
        if not document:
            return {'status': 'error', 'message': f'Document not found: {document_id}'}
        
        document.write({
            'state': 'processed',
            'extracted_data': json.dumps(data.get('data', {})),
            'processing_result': data.get('result', ''),
            'error_message': False
        })
        
        return {'status': 'success', 'message': 'Document processed successfully'}
    
    def _handle_analysis_completed(self, data):
        """Handle analysis_completed webhook event"""
        analysis_type = data.get('analysis_type')
        reference_id = data.get('reference_id')
        
        if not analysis_type or not reference_id:
            return {'status': 'error', 'message': 'Missing analysis_type or reference_id'}
        
        if analysis_type == 'crm':
            return self._handle_crm_analysis(data)
        elif analysis_type == 'project':
            return self._handle_project_analysis(data)
        else:
            return {'status': 'error', 'message': f'Unknown analysis type: {analysis_type}'}
    
    def _handle_crm_analysis(self, data):
        """Handle CRM analysis completion"""
        analysis_id = data.get('reference_id')
        if not analysis_id:
            return {'status': 'error', 'message': 'Missing reference_id'}
        
        analysis = request.env['manus.crm'].sudo().search([('id', '=', int(analysis_id))], limit=1)
        if not analysis:
            return {'status': 'error', 'message': f'CRM analysis not found: {analysis_id}'}
        
        analysis.write({
            'state': 'completed',
            'result_score': data.get('score', 0.0),
            'result_summary': data.get('summary', ''),
            'result_details': data.get('details', ''),
            'error_message': False
        })
        
        # Update lead if score is available
        if analysis.analysis_type == 'lead_scoring' and 'score' in data and analysis.lead_id:
            analysis.lead_id.write({
                'manus_score': data.get('score', 0.0),
                'manus_analysis_summary': data.get('summary', '')
            })
        
        return {'status': 'success', 'message': 'CRM analysis processed successfully'}
    
    def _handle_project_analysis(self, data):
        """Handle Project analysis completion"""
        analysis_id = data.get('reference_id')
        if not analysis_id:
            return {'status': 'error', 'message': 'Missing reference_id'}
        
        analysis = request.env['manus.project'].sudo().search([('id', '=', int(analysis_id))], limit=1)
        if not analysis:
            return {'status': 'error', 'message': f'Project analysis not found: {analysis_id}'}
        
        analysis.write({
            'state': 'completed',
            'result_summary': data.get('summary', ''),
            'result_details': data.get('details', ''),
            'error_message': False
        })
        
        # Update task if estimation is available
        if analysis.analysis_type == 'task_estimation' and 'estimated_hours' in data and analysis.task_id:
            analysis.task_id.write({
                'manus_estimated_hours': data.get('estimated_hours', 0.0),
                'manus_analysis_summary': data.get('summary', '')
            })
        
        return {'status': 'success', 'message': 'Project analysis processed successfully'}
