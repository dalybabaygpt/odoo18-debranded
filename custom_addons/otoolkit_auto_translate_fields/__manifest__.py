# -*- coding: utf-8 -*-
{
    'name': "Auto Translate Fields",
    'summary': "Seamlessly translate any translatable fields in Odoo across all available languages with a single click.",
    'description': """An Otoolkit app that allow you to seamlessly translate any translatable fields in Odoo across all available languages with a single click.""",
    'author': "Tipit",
    'website': "https://otoolkit.app/apps/auto-translate-fields",
    'category': 'Tools',
    'version': '18.0.0.0.1',
    'depends': ['web', 'otoolkit_auth'],
    "external_dependencies": {"python": ["requests"]},
    'assets': {
        'web.assets_backend': [
            'otoolkit_auto_translate_fields/static/src/js/translation_dialog_auto_translate.js',
            'otoolkit_auto_translate_fields/static/src/xml/translation_dialog_auto_translate.xml'
        ]
    },
    'maintainer': 'Tipit',
    'support': 'contact@otoolkit.app',
    'images': ['static/description/cover.gif'],
    'license': 'OPL-1',
    'installable': True,
    'application': True
}
