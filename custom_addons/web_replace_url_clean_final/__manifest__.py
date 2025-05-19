
{
    "name": "Web Replace URL Cleaner",
    "version": "1.0",
    "summary": "Cleans and replaces /odoo with /erp automatically",
    "author": "Custom",
    "depends": ["base"],
    "data": ["data/data.xml"],
    "post_init_hook": "run_post_install_hook",
    "installable": True,
    "auto_install": False,
    "application": False
}
