# SPDX-License-Identifier: GPL-3.0-or-later
"""Nautilus context menu: per-folder color from the Defenestra icon theme."""

import os.path

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gdk, Gio, GLib, GObject, Gtk, Nautilus

ICON_ATTR = "metadata::custom-icon-name"

COLORS = [
    ("defenestra", "Defenestra Blue"),
    ("defenestraorange", "Defenestra Orange"),
    ("defenestraslate", "Defenestra Slate"),
    ("blue", "Blue"),
    ("teal", "Teal"),
    ("green", "Green"),
    ("yellow", "Yellow"),
    ("orange", "Orange"),
    ("red", "Red"),
    ("pink", "Pink"),
    ("purple", "Purple"),
    ("slate", "Slate"),
    ("adwaita", "Adwaita"),
    ("black", "Black"),
    ("grey", "Grey"),
    ("white", "White"),
    ("brown", "Brown"),
    ("palebrown", "Pale Brown"),
    ("paleorange", "Pale Orange"),
    ("deeporange", "Deep Orange"),
    ("carmine", "Carmine"),
    ("magenta", "Magenta"),
    ("violet", "Violet"),
    ("indigo", "Indigo"),
    ("nordic", "Nordic"),
    ("bluegrey", "Blue Grey"),
    ("cyan", "Cyan"),
    ("darkcyan", "Dark Cyan"),
]

# Longest first, so defenestraorange is not read as defenestra plus a type.
COLOR_IDS = sorted((color for color, _ in COLORS), key=len, reverse=True)

# GIO names for known directories.
SPECIAL_STEMS = {
    "user-home": "user-{}-home",
    "user-desktop": "user-{}-desktop",
    "folder-documents": "folder-{}-documents",
    "folder-download": "folder-{}-download",
    "folder-music": "folder-{}-music",
    "folder-pictures": "folder-{}-pictures",
    "folder-publicshare": "folder-{}-publicshare",
    "folder-templates": "folder-{}-templates",
    "folder-videos": "folder-{}-videos",
}


def _icon_theme():
    return Gtk.IconTheme.get_for_display(Gdk.Display.get_default())


def _projects_dir():
    path = GLib.build_filenamev([GLib.get_user_config_dir(), "user-dirs.dirs"])
    try:
        _, data = GLib.file_get_contents(path)
    except GLib.Error:
        return None
    for line in data.decode().splitlines():
        if line.startswith("XDG_PROJECTS_DIR="):
            value = line.split("=", 1)[1].strip().strip('"')
            return os.path.realpath(value.replace("$HOME", GLib.get_home_dir()))
    return None


def _is_projects(gfile):
    path = gfile.get_path()
    return path is not None and os.path.realpath(path) == _projects_dir()


def _special_template(info):
    icon = info.get_icon()
    if isinstance(icon, Gio.ThemedIcon):
        for name in icon.get_names():
            if name in SPECIAL_STEMS:
                return SPECIAL_STEMS[name]
    return None


def _custom_kind(custom):
    """Folder type in a custom icon name: folder-red-code and folder-code both give "code"."""
    if not custom or not custom.startswith("folder-"):
        return ""
    rest = custom.removeprefix("folder-")
    for color in COLOR_IDS:
        if rest == color:
            return ""
        if rest.startswith(color + "-"):
            return rest.removeprefix(color + "-")
    return rest


def _folder_icons(gfile):
    """Icon name template with {} for the color, and the custom icon to restore on reset."""
    info = gfile.query_info(
        f"standard::icon,{ICON_ATTR}", Gio.FileQueryInfoFlags.NONE, None
    )
    special = _special_template(info)
    kind = _custom_kind(info.get_attribute_string(ICON_ATTR))
    if kind:
        template = f"folder-{{}}-{kind}"
        return template, None if template == special else f"folder-{kind}"
    if _is_projects(gfile):
        return "folder-{}-projects", "folder-projects"
    return special or "folder-{}", None


def _set_icon(gfile, name):
    if name:
        gfile.set_attribute_string(ICON_ATTR, name, Gio.FileQueryInfoFlags.NONE, None)
    else:
        gfile.set_attribute(
            ICON_ATTR,
            Gio.FileAttributeType.INVALID,
            None,
            Gio.FileQueryInfoFlags.NONE,
            None,
        )


def _refresh(gfile):
    path = gfile.get_path()
    try:
        st = os.stat(path)
        os.utime(path, ns=(st.st_atime_ns, st.st_mtime_ns))
    except OSError:
        pass


class DefenestraFolderColor(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        if not files or not all(
            f.is_directory() and f.get_uri_scheme() == "file" for f in files
        ):
            return []
        if not _icon_theme().has_icon("folder-defenestra"):
            return []

        top = Nautilus.MenuItem(name="DefenestraFolderColor::top", label="Folder Color")
        submenu = Nautilus.Menu()
        top.set_submenu(submenu)

        for color, label in COLORS:
            item = Nautilus.MenuItem(
                name=f"DefenestraFolderColor::{color}", label=label
            )
            item.connect("activate", self._on_color, files, color)
            submenu.append_item(item)

        reset = Nautilus.MenuItem(name="DefenestraFolderColor::reset", label="Default")
        reset.connect("activate", self._on_color, files, None)
        submenu.append_item(reset)
        return [top]

    def _on_color(self, _item, files, color):
        theme = _icon_theme()
        for f in files:
            gfile = f.get_location()
            template, reset = _folder_icons(gfile)
            if color is None:
                _set_icon(gfile, reset)
            else:
                name = template.format(color)
                _set_icon(gfile, name if theme.has_icon(name) else f"folder-{color}")
            _refresh(gfile)
