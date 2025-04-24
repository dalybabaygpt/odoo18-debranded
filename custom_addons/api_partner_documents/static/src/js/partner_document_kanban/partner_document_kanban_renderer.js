/** @odoo-module **/

import { useService } from "@web/core/utils/hooks";
import { KanbanRenderer } from "@web/views/kanban/kanban_renderer";
import { PartnerDocumentKanbanRecord } from "@api_partner_documents/js/partner_document_kanban/partner_document_kanban_record";
import { FileUploadProgressContainer } from "@web/core/file_upload/file_upload_progress_container";
import { FileUploadProgressKanbanRecord } from "@web/core/file_upload/file_upload_progress_record";

export class PartnerDocumentKanbanRenderer extends KanbanRenderer {
    setup() {
        super.setup();
        this.fileUploadService = useService("file_upload");
    }
}

PartnerDocumentKanbanRenderer.components = {
    ...KanbanRenderer.components,
    FileUploadProgressContainer,
    FileUploadProgressKanbanRecord,
    KanbanRecord: PartnerDocumentKanbanRecord,
};
PartnerDocumentKanbanRenderer.template = "api_partner_documents.PartnerDocumentKanbanRenderer";
