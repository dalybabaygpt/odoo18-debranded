# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
import logging

_logger = logging.getLogger(__name__)

class ManusProject(models.Model):
    _name = 'manus.project'
    _description = 'Manus Project Integration'
    
    name = fields.Char(string='Name', required=True)
    project_id = fields.Many2one('project.project', string='Related Project')
    task_id = fields.Many2one('project.task', string='Related Task')
    user_id = fields.Many2one('res.users', string='Responsible', default=lambda self: self.env.user)
    company_id = fields.Many2one('res.company', string='Company', default=lambda self: self.env.company)
    
    analysis_type = fields.Selection([
        ('task_estimation', 'Task Time Estimation'),
        ('resource_allocation', 'Resource Allocation'),
        ('risk_assessment', 'Risk Assessment'),
        ('dependency_analysis', 'Dependency Analysis'),
        ('custom', 'Custom Analysis'),
    ], string='Analysis Type', required=True)
    
    state = fields.Selection([
        ('draft', 'Draft'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ], string='Status', default='draft')
    
    result_summary = fields.Text(string='Summary')
    result_details = fields.Text(string='Details')
    error_message = fields.Text(string='Error Message')
    
    def action_analyze(self):
        """Perform the selected project analysis using Manus AI"""
        self.ensure_one()
        
        if not self.project_id and not self.task_id:
            self.write({
                'state': 'failed',
                'error_message': 'No project or task selected'
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
        
        # Check if project integration is enabled
        if not connector.enable_project_integration:
            self.write({
                'state': 'failed',
                'error_message': 'Project integration is not enabled in Manus settings'
            })
            return False
        
        try:
            # Set to processing state
            self.write({'state': 'processing'})
            
            # Prepare data
            payload = {
                'analysis_type': self.analysis_type,
            }
            
            # Add project data if available
            if self.project_id:
                project_data = {
                    'id': self.project_id.id,
                    'name': self.project_id.name,
                    'description': self.project_id.description or '',
                    'user_id': self.project_id.user_id.name if self.project_id.user_id else '',
                    'partner_id': self.project_id.partner_id.name if self.project_id.partner_id else '',
                    'date_start': self.project_id.date_start.isoformat() if self.project_id.date_start else '',
                    'date': self.project_id.date.isoformat() if hasattr(self.project_id, 'date') and self.project_id.date else '',
                }
                
                # Add tasks if available
                if hasattr(self.project_id, 'task_ids') and self.project_id.task_ids:
                    project_data['tasks'] = [{
                        'id': task.id,
                        'name': task.name,
                        'description': task.description or '',
                        'stage_id': task.stage_id.name if task.stage_id else '',
                        'user_id': task.user_id.name if task.user_id else '',
                        'date_deadline': task.date_deadline.isoformat() if task.date_deadline else '',
                        'planned_hours': task.planned_hours if hasattr(task, 'planned_hours') else 0,
                        'remaining_hours': task.remaining_hours if hasattr(task, 'remaining_hours') else 0,
                        'effective_hours': task.effective_hours if hasattr(task, 'effective_hours') else 0,
                    } for task in self.project_id.task_ids]
                
                payload['project'] = project_data
            
            # Add task data if available
            if self.task_id:
                task_data = {
                    'id': self.task_id.id,
                    'name': self.task_id.name,
                    'description': self.task_id.description or '',
                    'stage_id': self.task_id.stage_id.name if self.task_id.stage_id else '',
                    'user_id': self.task_id.user_id.name if self.task_id.user_id else '',
                    'project_id': self.task_id.project_id.name if self.task_id.project_id else '',
                    'date_deadline': self.task_id.date_deadline.isoformat() if self.task_id.date_deadline else '',
                    'planned_hours': self.task_id.planned_hours if hasattr(self.task_id, 'planned_hours') else 0,
                    'remaining_hours': self.task_id.remaining_hours if hasattr(self.task_id, 'remaining_hours') else 0,
                    'effective_hours': self.task_id.effective_hours if hasattr(self.task_id, 'effective_hours') else 0,
                }
                
                # Add subtasks if available
                if hasattr(self.task_id, 'child_ids') and self.task_id.child_ids:
                    task_data['subtasks'] = [{
                        'id': subtask.id,
                        'name': subtask.name,
                        'description': subtask.description or '',
                        'stage_id': subtask.stage_id.name if subtask.stage_id else '',
                        'user_id': subtask.user_id.name if subtask.user_id else '',
                        'date_deadline': subtask.date_deadline.isoformat() if subtask.date_deadline else '',
                        'planned_hours': subtask.planned_hours if hasattr(subtask, 'planned_hours') else 0,
                    } for subtask in self.task_id.child_ids]
                
                payload['task'] = task_data
            
            # Call Manus API
            response = connector.call_manus_api('project/analyze', method='POST', data=payload)
            
            if response:
                self.write({
                    'state': 'completed',
                    'result_summary': response.get('summary', ''),
                    'result_details': response.get('details', ''),
                    'error_message': False
                })
                
                # Update task if estimation is available
                if self.analysis_type == 'task_estimation' and self.task_id and 'estimated_hours' in response:
                    self.task_id.write({
                        'manus_estimated_hours': response.get('estimated_hours', 0.0),
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
            'result_summary': False,
            'result_details': False,
            'error_message': False
        })
        return True


class ProjectTask(models.Model):
    _inherit = 'project.task'
    
    manus_estimated_hours = fields.Float(string='Manus Estimated Hours', copy=False)
    manus_analysis_summary = fields.Text(string='Manus Analysis', copy=False)
    
    def action_analyze_with_manus(self):
        """Create and open a new Manus project analysis for this task"""
        self.ensure_one()
        
        # Create new analysis
        analysis = self.env['manus.project'].create({
            'name': f"Analysis for {self.name}",
            'task_id': self.id,
            'project_id': self.project_id.id if self.project_id else False,
            'analysis_type': 'task_estimation',
        })
        
        # Open the analysis form
        return {
            'name': _('Manus Analysis'),
            'view_mode': 'form',
            'res_model': 'manus.project',
            'res_id': analysis.id,
            'type': 'ir.actions.act_window',
            'target': 'current',
        }
