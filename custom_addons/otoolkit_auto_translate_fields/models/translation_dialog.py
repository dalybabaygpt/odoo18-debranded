import requests
import json

from odoo import models, api, _


class TranslationDialog(models.AbstractModel):
    _name = "translation.dialog"
    _description = "Translation Dialog"

    def otoolkit_api_translation(self, terms, updated_terms):
        base_language = self.env.user.lang
        api_key = self.env['ir.config_parameter'].sudo().get_param('otoolkit_api_key')
        if not api_key:
            return [False, _("Your API key is invalid. This may be due to an input error, deletion or deactivation of the key. Please check your Otoolkit settings."), "settings"]

        payload = json.dumps({
            "terms": terms,
            "updated_terms": updated_terms,
            "base_language": base_language,
            "odoo_user_id": self.env.user.id
        })
        headers = {
            'Odoo-Api-Key': api_key,
            'Content-Type': 'application/json'
        }
        url = "https://api.otoolkit.app/api/auto-translate-fields/translate/"
        response = requests.request("POST", url, headers=headers, data=payload)

        if response.status_code == 200:
            return [True, response.json(), ""]

        if response.status_code == 401:
            return [False, _("Your API key is invalid. This may be due to an input error, deletion or deactivation of the key. Please check your Otoolkit settings."), "settings"]

        if response.status_code == 400:
            error = response.json()
            if error["type"] == "empty_text":
                return [False, _("The default language text cannot be empty."), ""]
            if error["type"] == "insufficient_funds":
                return [False, _("You do not have enough credits to translate. Please add credits to your balance to use this function."), "credits"]

        return [False, _("An error has occurred, please try again later."), ""]

    @api.model
    def translate_text(self, terms, updated_terms):
        return self.otoolkit_api_translation(terms, updated_terms)
