let RingoverSDK = undefined;

function getOptions() {
    return {
        type: 'fixed',
        size: 'medium',
        container: null,
        position: {
            top: 'auto',
            bottom: '0px',
            left: 'auto',
            right: '0px',
        },
        animation: false,
        trayicon: true
    };
}

function initiateSdk() {
    if(typeof RingoverSDK !== "object" && typeof require !== "undefined") {
        RingoverSDK = require("@ringover_dialer/js/ringover-sdk");
	} else if (typeof RingoverSDK !== "object" && typeof this.RingoverSDK !== "undefined") {
	    RingoverSDK = this.RingoverSDK;
	}
	
	if (typeof RingoverSDK === "object" && typeof RingoverSDK.RingoverSDK !== "undefined") {
		RingoverSDK = RingoverSDK.RingoverSDK;
	}
	
    if ("undefined" === typeof RingoverSDK) {
        console.error('>>> Error loading Ringover SDK');
        return false;
    }

    let dialerSdk = new RingoverSDK(getOptions());
    dialerSdk.generate();

    if (dialerSdk.checkStatus()) {
        dialerSdk.hide();
        dialerSdk.on('ringingCall', (ev) => { if (!dialerSdk.isDisplay()) { dialerSdk.show(); } });
        console.log('>>> Ringover dialer is ready');
    }
    return dialerSdk;
}

function manageClickEvent(dialerSdk, ev) {
    let num = '';

    if (
        ev.target.tagName !== undefined
        && ev.target.tagName === 'A'
        && ev.target.outerHTML.includes('href="tel:')
    ) {
        num = ev.target.pathname;
    } else if (
        ev.target.parentElement !== undefined
        && ev.target.parentElement !== null
        && ev.target.parentElement.tagName !== undefined
        && ev.target.parentElement.tagName !== null
        && ev.target.parentElement.tagName === 'A'
        && ev.target.parentElement.outerHTML.includes('href="tel:')
    ) {
        num = ev.target.parentElement.pathname;
    }

    if (num !== '') {
        ev.preventDefault();
        ev.stopImmediatePropagation();
        ev.stopPropagation();

        popupDialerOnClick(dialerSdk, num);
    }
}

function popupDialerOnClick(dialerSdk, num) {
    if (dialerSdk.checkStatus) {
        dialerSdk.dial(num);
        dialerSdk.show();
    }
}

function isUserAgentIncompatible() {
    const regex = /iPhone|iPod/i;
    return regex.test(navigator.userAgent);
}

function mainFun() {
    if (isUserAgentIncompatible()) {
        console.log('>>> Ringover dialer is not supported by current device');
        return;
    }

    const dialerSdk = initiateSdk();
    if (!dialerSdk) {
        return;
    }

    document.addEventListener("click", (ev) => manageClickEvent(dialerSdk, ev), false);
}

// Document ready without JQuery
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mainFun);
} else {
  mainFun();
}
