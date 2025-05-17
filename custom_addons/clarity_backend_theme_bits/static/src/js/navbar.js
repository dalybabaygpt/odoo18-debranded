/** @odoo-module **/

import { NavBar } from "@web/webclient/navbar/navbar";
import { useService } from "@web/core/utils/hooks";
import { patch } from "@web/core/utils/patch";
import { useEnvDebugContext } from "@web/core/debug/debug_context";
import { useState } from "@odoo/owl";
import { rpc } from "@web/core/network/rpc";

patch(NavBar.prototype, {
    setup() {
        super.setup();
        this.debugContext = useEnvDebugContext();
        this.rpc = rpc;
        this.companyService = useService("company");
        this.currentCompany = this.companyService.currentCompany;
        this.menuService = useService("menu");
        this.state = useState({
            ...this.state,
            isSidebarOpen: false,
        });
        this.getMenuItemHref = this.getMenuItemHref.bind(this);
    },

    onNavBarDropdownItemSelection(menu) {
        if (menu) {
            this.menuService.selectMenu(menu);
        }
    },

    get currentApp() {
        return this.menuService.getCurrentApp();
    },

    getMenuItemHref(payload) {
        if (!payload || (!payload.actionPath && !payload.actionID)) {
            return "#";
        }
        return `/odoo/${payload.actionPath || "action-" + (payload.actionID || "")}`;
    },

    toggleSidebar(ev) {
        this.state.isSidebarOpen = !this.state.isSidebarOpen;
        const toggleEl = ev.currentTarget;
        toggleEl.classList.toggle("visible");
        toggleEl.classList.toggle("sidebar-open");
        const navWrapper = document.querySelector(".nav-wrapper-bits");
        if (navWrapper) {
            navWrapper.classList.toggle("toggle-show");
        }
    },

    BackMenuToggle() {
        const subMenu = document.querySelector(".sub-menu-dropdown.show");
        if (subMenu) {
            subMenu.classList.remove("show");
        }
    },

    get appsMenuProps() {
        return {
            getMenuItemHref: this.getMenuItemHref,
            onNavBarDropdownItemSelection: this.onNavBarDropdownItemSelection.bind(this),
            isSmall: this.state.isSmall,
        };
    },
});