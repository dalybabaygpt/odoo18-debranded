# -*- coding: utf-8 -*-
# See LICENSE file for full licensing details.
# See COPYRIGHT file for full copyright details.
# Developed by Bizmate - Unbox Solutions Co., Ltd.

{
    'name': 'Progressive Web App Icon',
    'version': '18.0.1.0.0',
    'license': 'LGPL-3',
    'author': 'Bizmate',
    'category': 'Technical Settings',
    'website': 'https://www.unboxsol.com',
    'live_test_url': 'https://bizmate18.unboxsol.com',
    'summary': 'Configure Odoo Progressive Web App Icon (PWA) (Support Multi-Company)',
    'price': 0,
    'currency': 'USD',
    'support': 'bizmate@unboxsol.com',

    'depends': [
        'base',
        'base_setup',
        'web'
    ],
    'data': [
        'views/manifest.xml',
        'views/res_config_settings_views.xml'
    ],
    'auto_install': False,
    'images': ['static/description/images/banner.gif'],
}
