// SPDX-License-Identifier: GPL-3.0-or-later
import * as SystemActions from 'resource:///org/gnome/shell/misc/systemActions.js';

const LOGOUT_ACTION_ID = 'logout';

export default class ShowLogout {
    enable() {
        const sa = SystemActions.getDefault();
        const proto = Object.getPrototypeOf(sa);
        this._orig = proto._updateLogout;
        proto._updateLogout = function () {
            this._actions.get(LOGOUT_ACTION_ID).available = true;
            this.notify('can-logout');
        };
        sa._updateLogout();
    }

    disable() {
        const sa = SystemActions.getDefault();
        const proto = Object.getPrototypeOf(sa);
        if (this._orig) {
            proto._updateLogout = this._orig;
        }
        sa._updateLogout();
        this._orig = null;
    }
}
