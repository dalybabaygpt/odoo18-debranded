# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
import logging

_logger = logging.getLogger(__name__)

class ManusCRM(models.Model):
    _name = 'manus.crm'
    _description = 'Manus CRM Integration'
    
    name = fields.Char(string='Name', required=True)
    lead_id = fields.Many2one('crm.lead', string='Related Lead/Opportunity')
    partner_id = fields.Many2one('res.partner', string='Customer', related='lead_id.partner_id', store=True)
    user_id = fields.Many2one('res.users', string='Salesperson', default=lambda self: self.env.user)
    company_id = fields.Many2one('res.company', string='Company', default=lambda self: self.env.company)
    
    analysis_type = fields.Selection([
        ('lead_scoring', 'Lead Scoring'),
        ('sentiment_analysis', 'Sentiment Analysis'),
        ('next_action', 'Next Action Prediction'),
        ('churn_risk', 'Churn Risk Assessment'),
        ('custom', 'Custom Analysis'),
    ], string='Analysis Type', required=True)
    
    state = fields.Selection([
        ('draft', 'Draft'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ], string='Status', default='draft')
    
    result_score = fields.Float(string='Score', help='Numerical result of the analysis (0-100)')
    result_summary = fields.Text(string='Summary')
    result_details = fields.Text(string='Details')
    error_message = fields.Text(string='Error Message')
    
    def action_analyze(self):
        """Perform the selected analysis using Manus AI"""
        self.ensure_one()
        
        if not self.lead_id:
            self.write({
                'state': 'failed',
                'error_message': 'No lead/opportunity selected'
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
        
        # Check if CRM integration is enabled
        if not connector.enable_crm_integration:
            self.write({
                'state': 'failed',
                'error_message': 'CRM integration is not enabled in Manus settings'
            })
            return False
        
        try:
            # Set to processing state
            self.write({'state': 'processing'})
            
            # Prepare lead data
            lead_data = {
                'id': self.lead_id.id,
                'name': self.lead_id.name,
                'partner_name': self.lead_id.partner_name or '',
                'contact_name': self.lead_id.contact_name or '',
                'email': self.lead_id.email_from or '',
                'phone': self.lead_id.phone or '',
                'description': self.lead_id.description or '',
                'type': self.lead_id.type,
                'priority': self.lead_id.priority,
                'stage_id': self.lead_id.stage_id.name,
                'tag_ids': self.lead_id.tag_ids.mapped('name'),
                'team_id': self.lead_id.team_id.name if self.lead_id.team_id else '',
                'user_id': self.lead_id.user_id.name if self.lead_id.user_id else '',
                'company_id': self.lead_id.company_id.name,
                'create_date': self.lead_id.create_date.isoformat() if self.lead_id.create_date else '',
                'date_deadline': self.lead_id.date_deadline.isoformat() if self.lead_id.date_deadline else '',
                'expected_revenue': self.lead_id.expected_revenue,
                'probability': self.lead_id.probability,
            }
            
            # Add activity data if available
            if hasattr(self.lead_id, 'activity_ids') and self.lead_id.activity_ids:
                lead_data['activities'] = [{
                    'summary': activity.summary or '',
                    'note': activity.note or '',
                    'date_deadline': activity.date_deadline.isoformat() if activity.date_deadline else '',
                    'state': activity.state,
                    'activity_type': activity.activity_type_id.name if activity.activity_type_id else '',
                } for activity in self.lead_id.activity_ids]
            
            # Call Manus API
            payload = {
                'lead': lead_data,
                'analysis_type': self.analysis_type,
            }
            
            response = connector.call_manus_api('crm/analyze', method='POST', data=payload)
            
            if response:
                self.write({
                    'state': 'completed',
                    'result_score': response.get('score', 0.0),
                    'result_summary': response.get('summary', ''),
                    'result_details': response.get('details', ''),
                    'error_message': False
                })
                
                # Update lead if score is available
                if self.analysis_type == 'lead_scoring' and 'score' in response:
                    self.lead_id.write({
                        'manus_score': response.get('score', 0.0),
                        'manus_analysis_summary': response.get('summary', '')
                    })
                
                return True
            else:
                self.write({
                    'state': 'failed',
                    'error_message': 'Failed to analyze with Manus API'
                })
                return False
                
        except Exception as e:
            self.write({
                'state': 'failed',
                'error_message': str(e)
            })
            _logger.exception(f"Error analyzing with Manus: {str(e)}")
            return False
    
    def action_reset_to_draft(self):
        """Reset analysis to draft state"""
        self.write({
            'state': 'draft',
            'result_score': 0.0,
            'result_summary': False,
            'result_details': False,
            'error_message': False
        })
        return True


class CRMLead(models.Model):
    _inherit = 'crm.lead'
    
    manus_score = fields.Float(string='Manus Score', help='AI-generated lead score (0-100)', copy=False)
    manus_analysis_summary = fields.Text(string='Manus Analysis', copy=False)
    
    def action_analyze_with_manus(self):
        """Create and open a new Manus CRM analysis for this lead"""
        self.ensure_one()
        
        # Create new analysis
        analysis = self.env['manus.crm'].create({
            'name': f"Analysis for {self.name}",
            'lead_id': self.id,
            'analysis_type': 'lead_scoring',
        })
        
        # Open the analysis form
        return {
            'name': _('Manus Analysis'),
            'view_mode': 'form',
            'res_model': 'manus.crm',
            'res_id': analysis.id,
            'type': 'ir.actions.act_window',
            'target': 'current',
        }
