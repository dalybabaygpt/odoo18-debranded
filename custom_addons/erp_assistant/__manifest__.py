# -*- coding: utf-8 -*-
{
    "name": "ERP Assistant",
    "version": "18.0.1.0.0",
    "category": "Productivity/Tools",
    "summary": "Floating assistant providing contextual help within the ERP.",
    "description": """
ERP Assistant
=============

Provides a floating assistant button in the ERP interface.

Features:
- Context-aware help based on the current screen/record.
- User-friendly interface.
- Debranded (uses "ERP" instead of "Odoo").
""",
    "author": "Manus",
    "website": "https://manus.ai",  # Replace with actual if available
    "depends": ["web"],
    "data": [
        # Views will be added here if needed
    ],
    "assets": {
        "web.assets_backend": [
            "erp_assistant/static/src/css/assistant_styles.css",
            "erp_assistant/static/src/js/assistant_widget.js",
            "erp_assistant/static/src/xml/assistant_templates.xml",
        ],
    },
    "installable": True,
    "application": False,
    "auto_install": False,
    "license": "LGPL-3",
}

