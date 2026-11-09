// SPDX-License-Identifier: GPL-3.0-or-later
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class NoStartupOverview {
    enable() {
        const hide = () => Main.overview.hide();
        // Wait until after the start up of the GNOME shell complete to avoid
        // causing an animation to wait forever.
        if (Main.layoutManager._startingUp) {
            this._sid = Main.layoutManager.connect('startup-complete', hide);
        } else {
            hide();
        }
    }

    disable() {
        if (this._sid) {
            Main.layoutManager.disconnect(this._sid);
            this._sid = null;
        }
    }
}
