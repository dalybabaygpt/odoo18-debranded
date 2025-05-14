# -*- coding: utf-8 -*-

import logging

from erp import api, fields, models, _
from erp.exceptions import UserError, ValidationError

_logger = logging.getLogger(__name__)


class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    app_saas_ok = fields.Boolean('Enable CN SaaS', default=True, config_parameter='app_saas_ok',
                                 help="Checked to Enable www.erpapp.cn cloud service.")
