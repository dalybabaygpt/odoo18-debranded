{
    "name": "ERP Remove Odoo Branding UI",
    "version": "1.2",
    "summary": "Removes Odoo branding from POS by replacing title and hiding logo via CSS.",
    "author": "Custom",
    "category": "Point of Sale",
    "depends": ["point_of_sale"],
    "data": [
        "views/assets.xml"
    ],
    "assets": {
        "point_of_sale._assets_pos": [
            "erp_remove_odoo_branding_ui/static/src/css/branding.css"
        ]
    },
    "installable": True,
    "auto_install": False
}
