# -*- coding: utf-8 -*-

from odoo import fields, models


class ResConfigSettings(models.TransientModel):
    _inherit = "res.config.settings"

    openapi_context_timeout = fields.Integer(string="Connect Timout", help="群聊中多少分钟以内的聊天信息作为上下文继续",
                                             config_parameter="app_chatgpt.openapi_context_timeout")
    openai_sync_config = fields.Selection([
        ('sync', 'Synchronous'),
        ('async', 'Asynchronous')
    ], string='Sync Config', default='sync', config_parameter="app_chatgpt.openai_sync_config")

    ai_chat_padding_time = fields.Integer(
        string="Ai Padding Time", default=0.0, config_parameter="app_chatgpt.ai_chat_padding_time",
        help="Amount of time (in seconds) between a conversation")
