# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
from odoo.exceptions import UserError
import requests
import json
import logging

_logger = logging.getLogger(__name__)

class ManusConnector(models.Model):
    _name = 'manus.connector'
    _description = 'Manus AI Connector'

    name = fields.Char(string='Name', required=True)
    api_key = fields.Char(string='API Key', required=True)
    api_endpoint = fields.Char(string='API Endpoint', required=True, default='https://api.manus.ai/v1')
    active = fields.Boolean(string='Active', default=True)
    state = fields.Selection([
        ('draft', 'Not Configured'),
        ('test', 'Test Connection'),
        ('production', 'Production'),
    ], string='Status', default='draft')
    last_connection = fields.Datetime(string='Last Connection')
    connection_status = fields.Selection([
        ('success', 'Success'),
        ('failed', 'Failed'),
    ], string='Connection Status')
    error_message = fields.Text(string='Error Message')
    
    # Feature toggles
    enable_document_processing = fields.Boolean(string='Enable Document Processing', default=True)
    enable_data_analysis = fields.Boolean(string='Enable Data Analysis', default=True)
    enable_workflow_automation = fields.Boolean(string='Enable Workflow Automation', default=True)
    enable_calendar_management = fields.Boolean(string='Enable Calendar Management', default=True)
    enable_customer_interaction = fields.Boolean(string='Enable Customer Interaction', default=True)
    
    # Module integration toggles
    enable_crm_integration = fields.Boolean(string='Enable CRM Integration', default=True)
    enable_project_integration = fields.Boolean(string='Enable Project Integration', default=True)
    enable_document_integration = fields.Boolean(string='Enable Document Integration', default=True)
    enable_hr_integration = fields.Boolean(string='Enable HR Integration', default=True)
    enable_website_integration = fields.Boolean(string='Enable Website Integration', default=True)
    enable_calendar_integration = fields.Boolean(string='Enable Calendar Integration', default=True)
    
    # Statistics
    request_count = fields.Integer(string='Request Count', default=0)
    success_count = fields.Integer(string='Success Count', default=0)
    failure_count = fields.Integer(string='Failure Count', default=0)
    
    @api.model
    def create(self, vals):
        # Ensure only one active connector exists
        if vals.get('active', True):
            active_connectors = self.search([('active', '=', True)])
            if active_connectors:
                active_connectors.write({'active': False})
        return super(ManusConnector, self).create(vals)
    
    def write(self, vals):
        # Ensure only one active connector exists
        if vals.get('active', False):
            active_connectors = self.search([('active', '=', True), ('id', '!=', self.id)])
            if active_connectors:
                active_connectors.write({'active': False})
        return super(ManusConnector, self).write(vals)
    
    def test_connection(self):
        """Test the connection to Manus API"""
        self.ensure_one()
        
        if not self.api_key or not self.api_endpoint:
            raise UserError(_("API Key and Endpoint must be configured."))
        
        try:
            headers = {
                'Authorization': f'Bearer {self.api_key}',
                'Content-Type': 'application/json'
            }
            
            response = requests.get(
                f"{self.api_endpoint}/status",
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                self.write({
                    'state': 'test',
                    'last_connection': fields.Datetime.now(),
                    'connection_status': 'success',
                    'error_message': False
                })
                return {
                    'type': 'ir.actions.client',
                    'tag': 'display_notification',
                    'params': {
                        'title': _('Connection Test'),
                        'message': _('Connection to Manus API successful!'),
                        'sticky': False,
                        'type': 'success',
                    }
                }
            else:
                self.write({
                    'last_connection': fields.Datetime.now(),
                    'connection_status': 'failed',
                    'error_message': f"Error {response.status_code}: {response.text}"
                })
                return {
                    'type': 'ir.actions.client',
                    'tag': 'display_notification',
                    'params': {
                        'title': _('Connection Test'),
                        'message': _(f"Connection failed: {response.text}"),
                        'sticky': False,
                        'type': 'danger',
                    }
                }
                
        except Exception as e:
            self.write({
                'last_connection': fields.Datetime.now(),
                'connection_status': 'failed',
                'error_message': str(e)
            })
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': _('Connection Test'),
                    'message': _(f"Connection failed: {str(e)}"),
                    'sticky': False,
                    'type': 'danger',
                }
            }
    
    def set_to_production(self):
        """Set the connector to production mode"""
        self.ensure_one()
        if self.state != 'test' or self.connection_status != 'success':
            raise UserError(_("You must successfully test the connection before setting to production."))
        
        self.write({'state': 'production'})
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': _('Production Mode'),
                'message': _('Connector set to production mode.'),
                'sticky': False,
                'type': 'success',
            }
        }
    
    def call_manus_api(self, endpoint, method='GET', data=None):
        """
        Call the Manus API with the given endpoint and method
        
        :param endpoint: API endpoint to call (without base URL)
        :param method: HTTP method (GET, POST, PUT, DELETE)
        :param data: Data to send in the request body
        :return: API response or False on error
        """
        self.ensure_one()
        
        if not self.active or self.state != 'production':
            _logger.warning("Manus connector is not active or not in production mode")
            return False
        
        try:
            headers = {
                'Authorization': f'Bearer {self.api_key}',
                'Content-Type': 'application/json'
            }
            
            url = f"{self.api_endpoint}/{endpoint.lstrip('/')}"
            
            self.request_count += 1
            
            if method == 'GET':
                response = requests.get(url, headers=headers, timeout=30)
            elif method == 'POST':
                response = requests.post(url, headers=headers, json=data, timeout=30)
            elif method == 'PUT':
                response = requests.put(url, headers=headers, json=data, timeout=30)
            elif method == 'DELETE':
                response = requests.delete(url, headers=headers, timeout=30)
            else:
                _logger.error(f"Unsupported HTTP method: {method}")
                self.failure_count += 1
                return False
            
            if response.status_code in (200, 201, 204):
                self.success_count += 1
                return response.json() if response.content else True
            else:
                _logger.error(f"Manus API error: {response.status_code} - {response.text}")
                self.failure_count += 1
                return False
                
        except Exception as e:
            _logger.exception(f"Error calling Manus API: {str(e)}")
            self.failure_count += 1
            return False
    
    @api.model
    def get_active_connector(self):
        """Get the active Manus connector"""
        connector = self.search([('active', '=', True), ('state', '=', 'production')], limit=1)
        if not connector:
            _logger.warning("No active Manus connector found")
            return False
        return connector
