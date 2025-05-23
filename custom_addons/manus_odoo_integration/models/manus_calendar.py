# -*- coding: utf-8 -*-
from odoo import models, fields, api, _
import logging

_logger = logging.getLogger(__name__)

class ManusCalendar(models.Model):
    _name = 'manus.calendar'
    _description = 'Manus Calendar Integration'
    
    name = fields.Char(string='Name', required=True)
    calendar_event_id = fields.Many2one('calendar.event', string='Related Calendar Event')
    user_id = fields.Many2one('res.users', string='Responsible', default=lambda self: self.env.user)
    company_id = fields.Many2one('res.company', string='Company', default=lambda self: self.env.company)
    
    optimization_type = fields.Selection([
        ('scheduling', 'Smart Scheduling'),
        ('attendee_suggestion', 'Attendee Suggestion'),
        ('duration_optimization', 'Duration Optimization'),
        ('location_suggestion', 'Location Suggestion'),
        ('custom', 'Custom Optimization'),
    ], string='Optimization Type', required=True)
    
    state = fields.Selection([
        ('draft', 'Draft'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ], string='Status', default='draft')
    
    result_summary = fields.Text(string='Summary')
    result_details = fields.Text(string='Details')
    error_message = fields.Text(string='Error Message')
    
    def action_optimize(self):
        """Perform the selected calendar optimization using Manus AI"""
        self.ensure_one()
        
        if not self.calendar_event_id:
            self.write({
                'state': 'failed',
                'error_message': 'No calendar event selected'
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
        
        # Check if calendar integration is enabled
        if not connector.enable_calendar_integration:
            self.write({
                'state': 'failed',
                'error_message': 'Calendar integration is not enabled in Manus settings'
            })
            return False
        
        try:
            # Set to processing state
            self.write({'state': 'processing'})
            
            # Prepare event data
            event_data = {
                'id': self.calendar_event_id.id,
                'name': self.calendar_event_id.name,
                'description': self.calendar_event_id.description or '',
                'start': self.calendar_event_id.start.isoformat() if self.calendar_event_id.start else '',
                'stop': self.calendar_event_id.stop.isoformat() if self.calendar_event_id.stop else '',
                'duration': self.calendar_event_id.duration,
                'location': self.calendar_event_id.location or '',
                'user_id': self.calendar_event_id.user_id.name if self.calendar_event_id.user_id else '',
            }
            
            # Add attendees if available
            if hasattr(self.calendar_event_id, 'partner_ids') and self.calendar_event_id.partner_ids:
                event_data['attendees'] = [{
                    'id': attendee.id,
                    'name': attendee.name,
                    'email': attendee.email or '',
                    'phone': attendee.phone or '',
                } for attendee in self.calendar_event_id.partner_ids]
            
            # Call Manus API
            payload = {
                'event': event_data,
                'optimization_type': self.optimization_type,
            }
            
            response = connector.call_manus_api('calendar/optimize', method='POST', data=payload)
            
            if response:
                self.write({
                    'state': 'completed',
                    'result_summary': response.get('summary', ''),
                    'result_details': response.get('details', ''),
                    'error_message': False
                })
                
                # Update calendar event if optimization data is available
                if self.optimization_type == 'duration_optimization' and 'optimized_duration' in response:
                    self.calendar_event_id.write({
                        'duration': response.get('optimized_duration', self.calendar_event_id.duration),
                        'manus_optimization_summary': response.get('summary', '')
                    })
                
                return True
            else:
                self.write({
                    'state': 'failed',
                    'error_message': 'Failed to optimize with Manus API'
                })
                return False
                
        except Exception as e:
            self.write({
                'state': 'failed',
                'error_message': str(e)
            })
            _logger.exception(f"Error optimizing with Manus: {str(e)}")
            return False
    
    def action_reset_to_draft(self):
        """Reset optimization to draft state"""
        self.write({
            'state': 'draft',
            'result_summary': False,
            'result_details': False,
            'error_message': False
        })
        return True


class CalendarEvent(models.Model):
    _inherit = 'calendar.event'
    
    manus_optimization_summary = fields.Text(string='Manus Optimization', copy=False)
    
    def action_optimize_with_manus(self):
        """Create and open a new Manus calendar optimization for this event"""
        self.ensure_one()
        
        # Create new optimization
        optimization = self.env['manus.calendar'].create({
            'name': f"Optimization for {self.name}",
            'calendar_event_id': self.id,
            'optimization_type': 'duration_optimization',
        })
        
        # Open the optimization form
        return {
            'name': _('Manus Optimization'),
            'view_mode': 'form',
            'res_model': 'manus.calendar',
            'res_id': optimization.id,
            'type': 'ir.actions.act_window',
            'target': 'current',
        }
