# -*- coding: utf-8 -*-

import json
import logging

from odoo import http
from odoo.http import request
from odoo.tools import html_escape

_logger = logging.getLogger(__name__)

# Define a list of common fields to check for context
COMMON_FIELDS = ["name", "display_name", "state", "email", "phone", "mobile", "partner_id", "user_id", "company_id", "date_order", "amount_total", "stage_id"]

class ErpAssistantController(http.Controller):

    def _get_field_value(self, record, field_name):
        """Safely get field value and handle relational fields."""
        if hasattr(record, field_name):
            value = getattr(record, field_name)
            # For relational fields (Many2one, Many2many, One2many), return display name or count
            if hasattr(value, "display_name") and not isinstance(value, (str, bool, int, float)):
                # Many2one: get display_name
                if len(value) == 1:
                    return value.display_name
                # Many2many/One2many: return count or list of names (limit length)
                elif len(value) > 1:
                    names = value[:5].mapped("display_name") # Limit to first 5 names
                    return f"{len(value)} records: {", ".join(names)}{"..." if len(value) > 5 else ""}"
                else:
                    return "Not set"
            return value
        return None

    @http.route("/erp_assistant/get_context", type="json", auth="user")
    def get_context_info(self, params):
        """Fetches context information and answers basic questions."""
        context_info = {
            "view_type": params.get("view_type"),
            "model": params.get("model"),
            "record_id": params.get("res_id"),
            "record_name": None,
            "record_data": {},
            "answer": None,
            "error": None,
        }

        model_name = context_info["model"]
        record_id = context_info["record_id"]
        user_question = params.get("question", "").lower().strip()

        if model_name:
            try:
                # Check model existence and access rights
                if model_name not in request.env:
                    context_info["error"] = f"Model 	{html_escape(model_name)}	 not found in ERP."
                    return context_info

                Model = request.env[model_name]
                if not Model.check_access_rights("read", raise_exception=False):
                    context_info["error"] = f"You do not have permission to read records from {html_escape(model_name)}."
                    return context_info

                # If a record ID is provided, fetch its details
                if record_id:
                    record = Model.browse(record_id).exists()
                    if record:
                        context_info["record_name"] = record.display_name
                        # Fetch common fields if they exist on the model
                        fields_to_read = [f for f in COMMON_FIELDS if f in record._fields]
                        record_values = record.read(fields_to_read, load=False)[0]
                        # Format values, especially relational ones
                        for field in fields_to_read:
                            context_info["record_data"][field] = self._get_field_value(record, field)

                        # --- Basic Question Answering --- 
                        if user_question:
                            found_answer = False
                            # Check if question asks for a specific field value
                            for field in fields_to_read:
                                if field.replace("_", " ") in user_question or field in user_question:
                                    value = context_info["record_data"].get(field)
                                    if value is not None:
                                        context_info["answer"] = f"The {field.replace("_", " ")} is: {html_escape(str(value))}"
                                        found_answer = True
                                        break
                            
                            if not found_answer:
                                # Add more sophisticated NLP/parsing later if needed
                                context_info["answer"] = "Sorry, I couldn't find that specific information in this record. Try asking about common fields like status, email, phone, or name."
                    else:
                        context_info["error"] = f"Record {record_id} not found in {html_escape(model_name)}."
                elif user_question:
                     context_info["answer"] = "I need a specific record context to answer questions about field values. Please navigate to a record first."

            except Exception as e:
                _logger.error("Error fetching ERP context for assistant: %s", e, exc_info=True)
                context_info["error"] = "An error occurred while fetching context."
        elif user_question:
            context_info["answer"] = "I need to know which part of the ERP you are viewing to help. Please navigate to a specific screen or record."

        return context_info

