# -*- coding: utf-8 -*-
from odoo import models, fields, api, _

class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'
    
    manus_api_key = fields.Char(related='company_id.manus_api_key', readonly=False, string='Manus API Key')
    manus_api_endpoint = fields.Char(related='company_id.manus_api_endpoint', readonly=False, 
                                    string='Manus API Endpoint', 
                                    default='https://api.manus.ai/v1')
    
    # Feature toggles
    manus_enable_document_processing = fields.Boolean(related='company_id.manus_enable_document_processing', 
                                                    readonly=False, 
                                                    string='Enable Document Processing')
    manus_enable_data_analysis = fields.Boolean(related='company_id.manus_enable_data_analysis', 
                                              readonly=False, 
                                              string='Enable Data Analysis')
    manus_enable_workflow_automation = fields.Boolean(related='company_id.manus_enable_workflow_automation', 
                                                    readonly=False, 
                                                    string='Enable Workflow Automation')
    manus_enable_calendar_management = fields.Boolean(related='company_id.manus_enable_calendar_management', 
                                                    readonly=False, 
                                                    string='Enable Calendar Management')
    manus_enable_customer_interaction = fields.Boolean(related='company_id.manus_enable_customer_interaction', 
                                                     readonly=False, 
                                                     string='Enable Customer Interaction')
    
    # Module integration toggles
    manus_enable_crm_integration = fields.Boolean(related='company_id.manus_enable_crm_integration', 
                                                readonly=False, 
                                                string='Enable CRM Integration')
    manus_enable_project_integration = fields.Boolean(related='company_id.manus_enable_project_integration', 
                                                    readonly=False, 
                                                    string='Enable Project Integration')
    manus_enable_document_integration = fields.Boolean(related='company_id.manus_enable_document_integration', 
                                                     readonly=False, 
                                                     string='Enable Document Integration')
    manus_enable_hr_integration = fields.Boolean(related='company_id.manus_enable_hr_integration', 
                                               readonly=False, 
                                               string='Enable HR Integration')
    manus_enable_website_integration = fields.Boolean(related='company_id.manus_enable_website_integration', 
                                                    readonly=False, 
                                                    string='Enable Website Integration')
    manus_enable_calendar_integration = fields.Boolean(related='company_id.manus_enable_calendar_integration', 
                                                     readonly=False, 
                                                     string='Enable Calendar Integration')
    
    def action_manus_test_connection(self):
        """Test the connection to Manus API from settings"""
        connector = self.env['manus.connector'].search([('active', '=', True)], limit=1)
        
        if not connector:
            # Create a new connector if none exists
            connector = self.env['manus.connector'].create({
                'name': 'Manus Connector',
                'api_key': self.manus_api_key,
                'api_endpoint': self.manus_api_endpoint,
                'active': True,
                'enable_document_processing': self.manus_enable_document_processing,
                'enable_data_analysis': self.manus_enable_data_analysis,
                'enable_workflow_automation': self.manus_enable_workflow_automation,
                'enable_calendar_management': self.manus_enable_calendar_management,
                'enable_customer_interaction': self.manus_enable_customer_interaction,
                'enable_crm_integration': self.manus_enable_crm_integration,
                'enable_project_integration': self.manus_enable_project_integration,
                'enable_document_integration': self.manus_enable_document_integration,
                'enable_hr_integration': self.manus_enable_hr_integration,
                'enable_website_integration': self.manus_enable_website_integration,
                'enable_calendar_integration': self.manus_enable_calendar_integration,
            })
        else:
            # Update existing connector
            connector.write({
                'api_key': self.manus_api_key,
                'api_endpoint': self.manus_api_endpoint,
                'enable_document_processing': self.manus_enable_document_processing,
                'enable_data_analysis': self.manus_enable_data_analysis,
                'enable_workflow_automation': self.manus_enable_workflow_automation,
                'enable_calendar_management': self.manus_enable_calendar_management,
                'enable_customer_interaction': self.manus_enable_customer_interaction,
                'enable_crm_integration': self.manus_enable_crm_integration,
                'enable_project_integration': self.manus_enable_project_integration,
                'enable_document_integration': self.manus_enable_document_integration,
                'enable_hr_integration': self.manus_enable_hr_integration,
                'enable_website_integration': self.manus_enable_website_integration,
                'enable_calendar_integration': self.manus_enable_calendar_integration,
            })
        
        return connector.test_connection()


class ResCompany(models.Model):
    _inherit = 'res.company'
    
    manus_api_key = fields.Char(string='Manus API Key')
    manus_api_endpoint = fields.Char(string='Manus API Endpoint', default='https://api.manus.ai/v1')
    
    # Feature toggles
    manus_enable_document_processing = fields.Boolean(string='Enable Document Processing', default=True)
    manus_enable_data_analysis = fields.Boolean(string='Enable Data Analysis', default=True)
    manus_enable_workflow_automation = fields.Boolean(string='Enable Workflow Automation', default=True)
    manus_enable_calendar_management = fields.Boolean(string='Enable Calendar Management', default=True)
    manus_enable_customer_interaction = fields.Boolean(string='Enable Customer Interaction', default=True)
    
    # Module integration toggles
    manus_enable_crm_integration = fields.Boolean(string='Enable CRM Integration', default=True)
    manus_enable_project_integration = fields.Boolean(string='Enable Project Integration', default=True)
    manus_enable_document_integration = fields.Boolean(string='Enable Document Integration', default=True)
    manus_enable_hr_integration = fields.Boolean(string='Enable HR Integration', default=True)
    manus_enable_website_integration = fields.Boolean(string='Enable Website Integration', default=True)
    manus_enable_calendar_integration = fields.Boolean(string='Enable Calendar Integration', default=True)
