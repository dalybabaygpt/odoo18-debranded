/** @odoo-module **/

import { Dropdown } from "@web/core/dropdown/dropdown";
import { DropdownItem } from "@web/core/dropdown/dropdown_item";
import { CheckBox } from "@web/core/checkbox/checkbox";
import { browser } from "@web/core/browser/browser";
import { registry } from "@web/core/registry";
import { Component } from "@odoo/owl";
import { user } from "@web/core/user";
import { session } from "@web/session";


const userMenuRegistry = registry.category("user_menuitems");

export class SidebarBottom extends Component {
    setup() {
        this.user = user;
        this.dbName = session.db;
        if (!this.user.userId || !this.env) {
            return; 
        }
        const { origin } = browser.location;
        this.source = `${origin}/web/image?model=res.users&field=avatar_128&id=${this.user.userId}`;
    }

    getElements() {
        const sortedItems = userMenuRegistry
            .getAll()
            .map((element) => element(this.env))
            .sort((x, y) => {
                const xSeq = x.sequence ? x.sequence : 100;
                const ySeq = y.sequence ? y.sequence : 100;
                return xSeq - ySeq;
            });
        return sortedItems;
    }
}

SidebarBottom.template = "SidebarBottom";
SidebarBottom.components = { Dropdown, DropdownItem, CheckBox };
SidebarBottom.props = {};

registry.category("systray").add("SidebarBottom", {
    Component: SidebarBottom,
    sequence: 100, // Increased to avoid conflicts with MessagingMenu
});