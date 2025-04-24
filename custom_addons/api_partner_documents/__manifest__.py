# -*- coding: utf-8 -*-
# Copyright (c) 2025-Present API SERVICE S.A.C. (<https://www.apiservicesac.com/>)
{
    'name': 'Partner Documents',

    'summary': """ 
        Manage and store documents associated with partners
    """,
    
    'description': """
        This module allows you to manage and store documents related to partners. 
        You can access the documents directly from the partner's section.
    """,

    'category': 'Document Management',
	'version': '18.0.0.0',
    'depends': ['contacts'],

    'license': 'OPL-1',
    'author': "API SERVICE S.A.C",
    'company': "API SERVICE S.A.C",
    'maintainer': "API SERVICE S.A.C",
    'website': "https://www.apiservicesac.com",
    #'price': 15.00,
    #'currency': 'USD',
	
    'data': [
        'security/ir.model.access.csv',
        'views/partner_documents_views.xml',        
        'views/res_partner_views.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'api_partner_documents/static/src/js/**/*',
        ],
    },

    'live_test_url': 'https://www.apiservicesac.com',
    'images': ['static/description/banner.jpg'],
}
