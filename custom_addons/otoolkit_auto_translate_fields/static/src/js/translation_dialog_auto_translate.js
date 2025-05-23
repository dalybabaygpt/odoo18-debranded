/** @odoo-module **/

import { TranslationDialog } from "@web/views/fields/translation_dialog";
import { patch } from "@web/core/utils/patch";
import { useService } from "@web/core/utils/hooks";
import { _t } from "@web/core/l10n/translation";

patch(TranslationDialog.prototype, {
    setup() {
        super.setup(...arguments);
        this.orm = useService('orm');
        this.notification = useService("notification")

        this.action = useService("action");
    },

    /**
     * Handler for the Auto Translate button.
     */
    async autoTranslate() {
        this.notification.add(_t("Translation in progress..."), { type: 'info'});
        const translatedTerms = await this._translateText(this.terms, this.updatedTerms);

        if (!translatedTerms[0]) {
            if (translatedTerms[2] === "credits") {
                return this.notification.add(translatedTerms[1], { type: 'danger', buttons: [{
                    onClick: () => window.open("https://otoolkit.app/pricing"),
                        primary: false,
                        name: _t("Get tokens")
                    }]});
            } else if (translatedTerms[2] === "settings") {
                return this.notification.add(translatedTerms[1], {
                    type: 'danger',
                    buttons: [{
                        onClick: () => this.action.doAction({
                            type: 'ir.actions.act_window',
                            res_model: 'res.config.settings',
                            views: [[false, 'form']],
                            target: 'current',
                            context: { module: 'otoolkit_auth' }
                        }),
                        primary: false,
                        name: _t("Open Settings")
                    }]
                });
            }
            return this.notification.add(translatedTerms[1], {type: 'danger'});
        }

        for (let term of translatedTerms[1]) {
            // Call a method to translate the text
            this.updatedTerms[term.id] = term.translation;
            this.terms.find(t => t.id === term.id).value = term.translation;
        }
        // Rerender the component to reflect changes
        this.render();
        return this.notification.add(_t("Successfully translated"), { type: 'success'});
    },

    /**
     * Method to translate text using a server-side method.
     */
    async _translateText(terms, updated_terms) {
        // Call a custom server method to perform translation
        return await this.orm.call("translation.dialog", "translate_text", [terms, updated_terms]);
    },

    async onSave() {
        const translations = {};

        this.terms.forEach((term) => {
            const updatedTermValue = this.updatedTerms[term.id];

            if (term.id in this.updatedTerms && updatedTermValue !== term.originalValue) {
                if (this.props.showSource) {
                    if (!translations[term.lang]) {
                        translations[term.lang] = {};
                    }
                    const oldTermValue = term.originalValue ? term.originalValue : term.source;
                    translations[term.lang][oldTermValue] = updatedTermValue || term.source;
                } else {
                    translations[term.lang] = updatedTermValue || false;
                }
            }
        });

        await this.orm.call(this.props.resModel, "update_field_translations", [
            [this.props.resId],
            this.props.fieldName,
            translations,
        ]);

        await this.props.onSave();
        this.props.close();
    },


});