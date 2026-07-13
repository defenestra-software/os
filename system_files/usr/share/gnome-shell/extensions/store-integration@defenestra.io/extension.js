// SPDX-License-Identifier: GPL-3.0-or-later
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Shell from 'gi://Shell';

import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import {AppMenu} from 'resource:///org/gnome/shell/ui/appMenu.js';

const USER_NAME = 'io.defenestra.Store.User';
const USER_PATH = '/io/defenestra/Store/User';
const SYSTEM_NAME = 'io.defenestra.Store.System';
const SYSTEM_PATH = '/io/defenestra/Store/System';

// Subset of the Store D-Bus API.
const storeIface = name => `
<node>
  <interface name="${name}">
    <method name="ListInstalled">
      <arg type="s" name="installed_json" direction="out"/>
    </method>
    <method name="Uninstall">
      <arg type="s" name="app_id" direction="in"/>
      <arg type="s" name="backend" direction="in"/>
      <arg type="s" name="operation_id" direction="out"/>
    </method>
    <signal name="OperationCompleted">
      <arg type="s" name="operation_id"/>
      <arg type="b" name="success"/>
      <arg type="s" name="message"/>
    </signal>
  </interface>
</node>`;

const UserProxy = Gio.DBusProxy.makeProxyWrapper(storeIface(USER_NAME));
const SystemProxy = Gio.DBusProxy.makeProxyWrapper(storeIface(SYSTEM_NAME));

const UninstallDialog = GObject.registerClass(
class UninstallDialog extends ModalDialog.ModalDialog {
    _init(launcher, entry, onConfirm) {
        super._init({styleClass: 'extension-dialog'});

        // No default button: Enter must not trigger a destructive action.
        this.setButtons([{
            label: 'Cancel',
            action: () => this.close(),
            key: Clutter.KEY_Escape,
        }, {
            label: 'Uninstall',
            action: () => {
                this.close();
                onConfirm();
            },
        }]);

        // Uninstalling any of a package's launchers takes the whole package, so
        // a secondary one has to say what really goes: nobody should remove all
        // of an app believing they removed only part of it.
        const secondary = entry.launchers > 1 && launcher !== entry.name;

        this.contentLayout.add_child(new Dialog.MessageDialogContent({
            title: `Uninstall ${secondary ? entry.name : launcher}?`,
            description: secondary
                ? `${launcher} is part of ${entry.name}. Uninstalling it removes ${entry.name} and everything else it installed.`
                : `${launcher} will be removed from your system.`,
        }));
    }
});

export default class StoreIntegration {
    enable() {
        this._index = new Map();
        this._menus = new Set();
        this._pending = new Map();
        this._refreshId = 0;

        // A proxy is only callable once its async init lands, so the first index
        // build is kicked off from there. _queueRefresh coalesces the two.
        const onReady = (proxy, error) => {
            if (error)
                logError(error, 'Store: could not reach the Store daemon');
            else
                this._queueRefresh();
        };
        this._user = new UserProxy(Gio.DBus.session, USER_NAME, USER_PATH, onReady);
        this._system = new SystemProxy(Gio.DBus.system, SYSTEM_NAME, SYSTEM_PATH, onReady);

        const onCompleted = (proxy, sender, params) => this._onOperationCompleted(params);
        this._userOpId = this._user.connectSignal('OperationCompleted', onCompleted);
        this._systemOpId = this._system.connectSignal('OperationCompleted', onCompleted);

        this._appSystem = Shell.AppSystem.get_default();
        this._installedId = this._appSystem.connect('installed-changed',
            () => this._queueRefresh());

        this._patchAppMenu();
    }

    disable() {
        if (this._refreshId) {
            GLib.Source.remove(this._refreshId);
            this._refreshId = 0;
        }

        this._appSystem.disconnect(this._installedId);
        this._appSystem = null;

        this._user.disconnectSignal(this._userOpId);
        this._system.disconnectSignal(this._systemOpId);
        this._user = null;
        this._system = null;

        const proto = AppMenu.prototype;
        delete proto.open;
        proto._updateDetailsVisibility = this._origUpdateDetails;
        this._origOpen = null;
        this._origUpdateDetails = null;

        for (const menu of this._menus) {
            menu.disconnect(menu._defenestraDestroyId);
            menu._defenestraItems.details.destroy();
            menu._defenestraItems.uninstall.destroy();
            delete menu._defenestraItems;
            delete menu._defenestraDestroyId;
            // Force hide the built-in item for Uninstall
            menu._updateDetailsVisibility();
        }
        this._menus.clear();

        this._menus = null;
        this._index = null;
        this._pending = null;
    }

    _patchAppMenu() {
        const proto = AppMenu.prototype;

        // AppMenu inherits open() from PopupMenu and never overrides it, so this
        // installs an own property that disable() deletes again.
        this._origOpen = proto.open;
        this._origUpdateDetails = proto._updateDetailsVisibility;

        const self = this;

        proto.open = function (animate) {
            self._addItems(this);
            self._updateItems(this);
            self._origOpen.call(this, animate);
        };

        // The stock "App Details" item is tied to org.gnome.Software.
        // So keep it hidden and replace it.
        proto._updateDetailsVisibility = function () {
            this._detailsItem.visible = false;
        };
    }

    _addItems(menu) {
        if (menu._defenestraItems)
            return;

        const details = new PopupMenu.PopupMenuItem('Show in Store');
        details.connect('activate', () => {
            Main.overview.hide();
            this._openInStore(menu._app);
        });

        const uninstall = new PopupMenu.PopupMenuItem('Uninstall…');
        uninstall.connect('activate', () => {
            Main.overview.hide();
            this._confirmUninstall(menu._app);
        });

        const at = menu._getMenuItems().indexOf(menu._detailsItem);
        menu.addMenuItem(details, at + 1);
        menu.addMenuItem(uninstall, at + 2);

        menu._defenestraItems = {details, uninstall};
        menu._defenestraDestroyId = menu.connect('destroy',
            () => this._menus.delete(menu));
        this._menus.add(menu);
    }

    _updateItems(menu) {
        const visible = this._lookup(menu._app) !== null;
        menu._defenestraItems.details.visible = visible;
        menu._defenestraItems.uninstall.visible = visible;
    }

    // _lookup resolves a Shell.App to the Store's identity triple. Anything the
    // Store cannot act on resolves to null and keeps its menu items hidden.
    _lookup(app) {
        const id = app?.get_id();
        if (!id)
            return null;
        return this._index.get(id) ?? null;
    }

    _queueRefresh() {
        if (this._refreshId)
            GLib.Source.remove(this._refreshId);

        this._refreshId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this._refreshId = 0;
            this._refreshIndex();
            return GLib.SOURCE_REMOVE;
        });
    }

    _refreshIndex(attempt = 0) {
        const rows = {};
        let failed = false;

        const collect = (from, json) => {
            rows[from] = json;
            if (rows.system === undefined || rows.user === undefined)
                return;
            // User scope shadows system scope
            const index = new Map();
            for (const scope of ['system', 'user'])
                this._ingest(index, rows[scope], scope);

            this._index = index;
            for (const menu of this._menus)
                this._updateItems(menu);

            // Handle daemon not already started
            if (failed && attempt === 0) {
                this._refreshId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
                    this._refreshId = 0;
                    this._refreshIndex(1);
                    return GLib.SOURCE_REMOVE;
                });
            }
        };

        const list = (proxy, scope) => {
            proxy.ListInstalledRemote((result, error) => {
                if (error) {
                    failed = true;
                    logError(error, `Store: ListInstalled failed (${scope})`);
                    collect(scope, '[]');
                    return;
                }
                collect(scope, result[0]);
            });
        };

        list(this._system, 'system');
        list(this._user, 'user');
    }

    _ingest(index, json, scope) {
        let installed;
        try {
            installed = JSON.parse(json);
        } catch (e) {
            logError(e, `Store: malformed ListInstalled payload (${scope})`);
            return;
        }

        for (const pkg of installed ?? []) {
            if (!pkg.id || !pkg.backend)
                continue;

            const desktopIDs = pkg.desktop_ids ?? [];
            const entry = {
                id: pkg.id,
                backend: pkg.backend,
                scope: pkg.scope || scope,
                name: pkg.name || pkg.id,
                launchers: desktopIDs.length,
            };

            for (const desktopID of desktopIDs) {
                if (index.has(desktopID)) {
                    const seen = index.get(desktopID);
                    if (seen === null || seen.backend !== entry.backend) {
                        index.set(desktopID, null);
                        continue;
                    }
                }
                index.set(desktopID, entry);
            }
        }
    }

    _openInStore(app) {
        const entry = this._lookup(app);
        if (!entry)
            return;

        try {
            Gio.Subprocess.new([
                'defenestra-store',
                `--details=${entry.id}`,
                `--backend=${entry.backend}`,
                `--scope=${entry.scope}`,
            ], Gio.SubprocessFlags.NONE);
        } catch (e) {
            logError(e, 'Store: could not launch defenestra-store');
            Main.notifyError('Store', 'Could not open the Store.');
        }
    }

    _confirmUninstall(app) {
        const entry = this._lookup(app);
        if (!entry)
            return;

        const launcher = app.get_name() || entry.name;
        new UninstallDialog(launcher, entry, () => this._uninstall(entry, entry.name)).open();
    }

    _uninstall(entry, name) {
        const proxy = entry.scope === 'system' ? this._system : this._user;

        Main.notify('Store', `Removing ${name}…`);

        proxy.UninstallRemote(entry.id, entry.backend, (result, error) => {
            if (error) {
                logError(error, `Store: uninstall failed (${entry.id})`);
                Main.notifyError(`Could not uninstall ${name}`, error.message);
                return;
            }
            this._pending.set(result[0], name);
        });
    }

    _onOperationCompleted([opID, success, message]) {
        const name = this._pending.get(opID);
        if (name === undefined)
            return;

        this._pending.delete(opID);
        this._queueRefresh();

        if (success)
            Main.notify('Store', `${name} was removed.`);
        else
            Main.notifyError(`Could not uninstall ${name}`, message);
    }
}
