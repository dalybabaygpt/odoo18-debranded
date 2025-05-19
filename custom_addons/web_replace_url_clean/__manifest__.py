{
    "name": "Web Replace URL Cleaner",
    "version": "1.1",
    "category": "Tools",
    "summary": "Fixes base URL and removes /odoo redirect loops.",
    "depends": ["base"],
    "installable": True,
    "auto_install": False,
    "post_init_hook": "run_post_install_hook",
    "license": "LGPL-3"
}
