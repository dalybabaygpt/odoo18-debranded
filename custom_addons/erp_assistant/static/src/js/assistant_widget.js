/** @odoo-module **/

import { registry } from "@web/core/registry";
import { Component, useState, onWillStart, onMounted, useRef } from "@odoo/owl";
import { useService } from "@web/core/utils/hooks";

class ErpAssistantButton extends Component {
    static template = "erp_assistant.FloatingButton";

    setup() {
        this.action = useService("action");
    }

    _onButtonClick() {
        // Trigger an event or call a method to open the panel
        this.env.bus.trigger("ERP_ASSISTANT:TOGGLE_PANEL");
    }
}

class ErpAssistantPanel extends Component {
    static template = "erp_assistant.AssistantPanel";

    setup() {
        this.state = useState({
            isOpen: false,
            isLoading: true,
            contextInfo: {},
        });
        this.rpc = useService("rpc");
        this.action = useService("action");
        this.env.bus.on("ERP_ASSISTANT:TOGGLE_PANEL", this, this._togglePanel);

        onWillStart(async () => {
            // Initial context fetch can happen here or when opening
        });

        onMounted(() => {
            // Add event listener for view changes if needed
            this.env.bus.on("ACTION_MANAGER:UPDATE", this, this._onViewChange);
        });

        this.inputRef = useRef("assistantInput");
    }

    _togglePanel() {
        this.state.isOpen = !this.state.isOpen;
        if (this.state.isOpen) {
            this._fetchContext();
        }
    }

    _onCloseClick() {
        this.state.isOpen = false;
    }

    _onViewChange() {
        // Refetch context if the panel is open when the view changes
        if (this.state.isOpen) {
            this._fetchContext();
        }
    }

    async _fetchContext(question = null) {
        this.state.isLoading = true;
        const currentAction = this.action.currentController;
        let params = {};
        if (currentAction) {
            const actionState = currentAction.actionPager ? currentAction.actionPager.state : currentAction.state;
            params = {
                view_type: actionState?.viewType,
                model: actionState?.resModel,
                res_id: actionState?.resId,
                context: actionState?.context,
                question: question, // Pass user question if any
            };
        }

        try {
            const result = await this.rpc("/erp_assistant/get_context", { params });
            this.state.contextInfo = result;
        } catch (error) {
            console.error("Error fetching ERP Assistant context:", error);
            this.state.contextInfo = { error: "Could not fetch context." };
        } finally {
            this.state.isLoading = false;
        }
    }

    _onInputKeyup(ev) {
        if (ev.key === "Enter") {
            const question = ev.target.value;
            if (question.trim()) {
                this._fetchContext(question.trim());
                ev.target.value = ""; // Clear input after sending
            }
        }
    }
}

// Add the components to the Systray registry or another suitable place
// For simplicity, we might add them to the main web client body.
// A better approach might involve a dedicated service or registry.

// This is a simplified way to add it globally. Needs refinement for proper integration.
registry.category("main_components").add("ErpAssistantButton", {
    Component: ErpAssistantButton,
});

registry.category("main_components").add("ErpAssistantPanel", {
    Component: ErpAssistantPanel,
});

