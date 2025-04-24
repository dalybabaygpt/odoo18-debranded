/** @odoo-module **/

import { registry } from "@web/core/registry";

import { kanbanView } from "@web/views/kanban/kanban_view";
import { PartnerDocumentKanbanController } from "@api_partner_documents/js/partner_document_kanban/partner_document_kanban_controller";
import { PartnerDocumentKanbanRenderer } from "@api_partner_documents/js/partner_document_kanban/partner_document_kanban_renderer";

export const partnerDocumentKanbanView = {
    ...kanbanView,
    Controller: PartnerDocumentKanbanController,
    Renderer: PartnerDocumentKanbanRenderer,
    buttonTemplate: "api_partner_documents.PartnerDocumentKanbanView.Buttons",
};

registry.category("views").add("partner_documents_kanban", partnerDocumentKanbanView);
