// SPDX-License-Identifier: GPL-3.0-or-later
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class NoStartupOverview {
    enable() {
        const hide = () => Main.overview.hide();
        if (Main.layoutManager._startingUp) {
            this._sid = Main.layoutManager.connect('startup-complete', hide);
        }
        hide();
    }

    disable() {
        if (this._sid) {
            Main.layoutManager.disconnect(this._sid);
            this._sid = null;
        }
    }
}
