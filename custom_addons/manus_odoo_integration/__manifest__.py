# -*- coding: utf-8 -*-
{
    'name': 'Manus AI Integration',
    'version': '1.0',
    'category': 'Productivity',
    'summary': 'Integrate Manus AI capabilities with Odoo',
    'description': """
Manus AI Integration for Odoo
=============================
This module integrates Manus AI capabilities with Odoo CE 18, providing:
- Document processing and auto-filling
- Intelligent data analysis
- Automated workflows
- Smart scheduling and calendar management
- Enhanced customer interactions

Integrates with CRM, Project, Documents, HR, Website, and Calendar modules.
""",
    'author': 'Manus',
    'website': 'https://manus.ai',
    'depends': [
        'base',
        'base_setup',
        'crm',
        'project',
        'document',
        'hr',
        'website',
        'calendar',
    ],
    'data': [
        'security/manus_security.xml',
        'security/ir.model.access.csv',
        'views/manus_settings_views.xml',
        'views/manus_dashboard_views.xml',
        'views/crm_views.xml',
        'views/project_views.xml',
        'views/document_views.xml',
        'views/hr_views.xml',
        'views/website_views.xml',
        'views/calendar_views.xml',
        'views/res_config_settings_views.xml',
        'data/manus_data.xml',
        'data/cron_jobs.xml',
    ],
    'demo': [
        'demo/manus_demo.xml',
    ],
    'images': ['static/description/banner.png'],
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
    'assets': {
        'web.assets_backend': [
            'manus_odoo_integration/static/src/js/manus_dashboard.js',
            'manus_odoo_integration/static/src/css/manus_dashboard.css',
        ],
        'web.assets_qweb': [
            'manus_odoo_integration/static/src/xml/manus_dashboard.xml',
        ],
    },
}
