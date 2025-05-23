# -*- coding: utf-8 -*-
{
    'name': "Otoolkit",
    'summary': "This app is the basic block of the Otoolkit integration. It allows you to connect your Otoolkit account to your Odoo instance.",
    'description': """""",
    'author': "Tipit",
    'website': "https://otoolkit.app",
    'category': 'Other',
    'version': '18.0.0.0.0',
    'depends': [],
    "external_dependencies": {"python": ["requests"]},
    'data': [
        # views
        "views/res_config_settings_views.xml",

        # data
        "data/data.xml"
    ],
    'maintainer': 'Tipit',
    'support': 'contact@otoolkit.app',
    'images': ['static/description/cover.jpeg'],
    'license': 'OPL-1',
    'installable': True,
    'application': True,
}
