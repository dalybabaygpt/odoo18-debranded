{
    "name": "Tashil Website PWA",
    "summary": "Adds PWA support to the website frontend and portal with caching, offline fallback, and install prompts",
    "version": "1.0.4",
    "category": "Website",
    "author": "You",
    "license": "LGPL-3",
    "depends": ["website"],
    "data": [
        "views/website_templates.xml"
    ],
    "assets": {
        "web.assets_frontend": [
            "/tashil_website_pwa/static/src/js/pwa_register.js",
            "/tashil_website_pwa/static/src/js/install_prompt.js"
        ]
    },
    "installable": True,
    "application": False
}