{
    'name': 'Remove POS Logo',
    'version': '1.0',
    'category': 'Point of Sale',
    'summary': 'Removes the logo inside POS screen (top-left)',
    'depends': ['point_of_sale'],
    'data': ['views/assets.xml'],
    'assets': {
        'point_of_sale.assets': [
            'pos_remove_logo/static/src/css/hide_pos_logo.css',
        ],
    },
    'installable': True,
    'auto_install': False,
}
