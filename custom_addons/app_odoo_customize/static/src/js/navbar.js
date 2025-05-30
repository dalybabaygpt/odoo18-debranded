/** @odoo-module **/

import { browser } from "@web/core/browser/browser";
import {NavBar} from '@web/webclient/navbar/navbar';
import {useEffect, useRef} from '@odoo/owl';
import { patch } from "@web/core/utils/patch";
import { renderToString } from "@web/core/utils/render";

patch(NavBar.components.MenuDropdown.prototype, {
    setup() {
        super.setup();
        //todo:  鼠标移开要不显示，当前太妨碍
        useEffect(() => this.addDebugTooltip());
    },
    addDebugTooltip() {
        let is_asset = browser.location.search.includes('?debug=assets');
        if (is_asset) {
            let dropdownDebugData = this.getDebugData()
            $(this.rootRef.el).find('.dropdown-toggle')
                .removeAttr('title')
                .tooltip(this.getDebugTooltip(dropdownDebugData));
            var self = this;
            _.each($(this.rootRef.el).find('.dropdown-menu_group'), function (menuGroup, index) {
                let $menuGroup = $(menuGroup);
                let menuGroupDebugData = self.getMenuGroupDebugData($menuGroup);
                $menuGroup.tooltip(self.getDebugTooltip(menuGroupDebugData));
            })
        }
    },
    getDebugData() {
        return {
            title: this.props.payload.name,
            xmlid: this.props.payload.xmlid,
            sequence: this.props.payload.sequence,
        }
    },
    getMenuGroupDebugData($menuGroup) {
        return {
            title: $menuGroup.data('name'),
            xmlid: $menuGroup.data('xmlid'),
            sequence: $menuGroup.data('sequence'),
        }
    },
    getDebugTooltip(debugData) {
        return {
            template: '<div class="tooltip tooltip-field-info" role="tooltip"><div class="arrow"></div><div class="tooltip-inner"></div></div>',
            title: renderToString('Menu.tooltip', debugData),
        };
    }
})
NavBar.components.MenuDropdown.props.payload = {
    type: Object,
    optional: true,
};
patch(NavBar.components.DropdownItem.prototype, {
    setup() {
        super.setup();
        //todo:  鼠标移开要不显示，当前太妨碍
        useEffect(() => this.addDebugTooltip());
    },
    addDebugTooltip() {
        let is_asset = browser.location.search.includes('?debug=assets');
        if (is_asset) {
            let menuDebugData = this.getDebugData();
            if (!menuDebugData) {
                return;
            }
            $(`.dropdown-item[data-menu-xmlid="${menuDebugData.xmlid}"], .dropdown-item[data-section="${menuDebugData.id}"]`)
                .removeAttr('title')
                .tooltip(this.getDebugTooltip(menuDebugData));
        }
    },
    getDebugData() {
        if (!this.props.payload) {
            return null;
        }
        return {
            id: this.props.payload.id,
            title: this.props.payload.name,
            xmlid: this.props.payload.xmlid,
            sequence: this.props.payload.sequence,
        }
    },
    getDebugTooltip(debugData) {
        return {
            template: '<div class="tooltip tooltip-field-info" role="tooltip"><div class="arrow"></div><div class="tooltip-inner"></div></div>',
            title: renderToString('Menu.tooltip', debugData),
        };
    }
})

NavBar.components.DropdownItem.props.payload = {
    type: Object,
    optional: true,
};
