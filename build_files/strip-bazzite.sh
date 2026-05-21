#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -ouex pipefail

echo ":: Stripping bazzite branding and onboarding..."

# Verified against bazzite 43.20260403.0 (Silverblue).
dnf5 remove -y --noautoremove bazaar
dnf5 remove -y --noautoremove bazzite-portal
dnf5 remove -y --noautoremove webapp-manager

rm -rf /usr/share/ublue-os/bazzite/
find /usr/share/icons/hicolor -name 'bazzite-*' -delete 2>/dev/null || true

rm -f /etc/xdg/autostart/bazzite-announcement.desktop
rm -f /usr/libexec/bazzite-announcement
rm -rf /usr/share/ublue-os/announcements/
rm -rf /usr/share/yafti/

rm -f /usr/share/applications/bazzite-documentation.desktop
rm -f /usr/share/applications/discourse.desktop
rm -f /usr/share/applications/system-update.desktop
rm -f /usr/share/applications/bbrew.desktop

rm -f /usr/bin/bruh

rm -rf /usr/share/ublue-os/bazaar/

rm -rf /usr/share/ublue-os/motd/
rm -f /usr/libexec/ublue-motd
rm -f /etc/profile.d/user-motd.sh
if [ -f /usr/share/fish/functions/fish_greeting.fish ]; then
    sed -i '/ublue-motd/d' /usr/share/fish/functions/fish_greeting.fish
fi

rm -f /etc/dconf/db/distro.d/10-bazzite-deck-silverblue-logomenu 2>/dev/null || true

# Our overrides ship via system_files overlay.
rm -f /usr/share/glib-2.0/schemas/zz0-*bazzite*.gschema.override 2>/dev/null || true

if [ -f /etc/xdg/mimeapps.list ]; then
    sed -i '/bazaar/d' /etc/xdg/mimeapps.list
fi

# Disable originals so they don't conflict during rename. install-defenestra.sh
# re-enables them under the new names.
systemctl disable bazzite-flatpak-manager.service 2>/dev/null || true
systemctl disable bazzite-hardware-setup.service 2>/dev/null || true
systemctl disable bazzite-libvirtd-setup.service 2>/dev/null || true
systemctl --global disable bazzite-dynamic-fixes.service 2>/dev/null || true
systemctl --global disable bazzite-user-setup.service 2>/dev/null || true
systemctl disable bazzite-tdpfix.service 2>/dev/null || true
systemctl disable bazzite-autologin.service 2>/dev/null || true

echo ":: Bazzite stripping complete."
