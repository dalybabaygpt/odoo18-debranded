{
        'name': 'PWA Website App',
        'version': '1.0',
        'category': 'Website',
        'summary': 'Installable PWA with offline, push notifications, and sync',
        'depends': ['website'],
        'data': ['views/pwa_templates.xml'],
        'assets': {
            'web.assets_frontend': [
                'pwa_website_app/static/src/js/pwa.js',
                'pwa_website_app/static/src/css/pwa.css',
            ],
        },
        'installable': True,
        'application': True,
    }