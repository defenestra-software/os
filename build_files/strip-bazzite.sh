#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -ouex pipefail

echo ":: Stripping bazzite branding and onboarding..."

# Verified against bazzite 44.20260825 (Silverblue).
dnf5 remove -y --noautoremove bazaar
dnf5 remove -y --noautoremove bazzite-portal
dnf5 remove -y --noautoremove webapp-manager

dnf5 remove -y --noautoremove bazzite-updater
rm -f /usr/share/ublue-os/just/93-bazzite-update.just
sed -i '\|/usr/share/ublue-os/just/93-bazzite-update.just|d' /usr/share/ublue-os/justfile

# Bazzite default desktop
rm -f /usr/share/ublue-os/just/90-bazzite-de.just
sed -i '\|/usr/share/ublue-os/just/90-bazzite-de.just|d' /usr/share/ublue-os/justfile
rm -rf /usr/share/ublue-os/dconfs/

# Drop bazzite homebrew unit
rm -f /usr/lib/systemd/system-preset/01-homebrew.preset

rm -rf /usr/share/ublue-os/bazzite/
find /usr/share/icons/hicolor -name 'bazzite-*' -delete 2>/dev/null || true

rm -f /etc/xdg/autostart/bazzite-announcement.desktop
rm -f /usr/libexec/bazzite-announcement
rm -rf /usr/share/ublue-os/announcements/
rm -rf /usr/share/yafti/

rm -f /etc/skel/.config/autostart/bazzite-portal.desktop
rm -f /etc/skel/.config/autostart/steam.desktop

rm -f /usr/share/applications/bazzite-documentation.desktop
rm -f /usr/share/applications/discourse.desktop
rm -f /usr/share/applications/system-update.desktop
rm -f /usr/share/applications/bbrew.desktop

rm -f /usr/bin/bruh

rm -rf /usr/share/ublue-os/bazaar/

# Steam Deck branding: Valve trademark/copyright. ublue.png/ublue.xml stay (base lineage).
dnf5 remove -y --noautoremove steamdeck-backgrounds
rm -rf /usr/share/backgrounds/steamdeck/
rm -rf /usr/share/backgrounds/convergence /usr/share/backgrounds/convergence.jxl /usr/share/backgrounds/convergence-dynamic.xml
rm -f /usr/share/backgrounds/giants.jxl
rm -f /usr/share/backgrounds/default.jxl /usr/share/backgrounds/default-dark.jxl
rm -f /usr/share/backgrounds/bazzite-blue.png /usr/share/backgrounds/bazzite-glass.png

rm -f /usr/share/gnome-background-properties/convergence.xml \
      /usr/share/gnome-background-properties/convergence-dynamic.xml \
      /usr/share/gnome-background-properties/VGUI2.xml \
      /usr/share/gnome-background-properties/bazziteblue.xml \
      /usr/share/gnome-background-properties/glass.xml \
      /usr/share/gnome-background-properties/giants.xml

rm -rf /usr/share/ublue-os/motd/
rm -f /usr/libexec/ublue-motd
rm -f /etc/profile.d/user-motd.sh
if [ -f /usr/share/fish/functions/fish_greeting.fish ]; then
      sed -i '/ublue-motd/d' /usr/share/fish/functions/fish_greeting.fish
fi

rm -f /etc/dconf/db/distro.d/10-bazzite-deck-silverblue-logomenu 2>/dev/null || true

# Bazzite's bluez 5.87 (git.7950.32d2ebd9.dirty) segfaults in device_found_callback
# on LE discovery. Drop this distro-sync once their build stops crashing.
dnf5 versionlock delete bluez bluez-libs bluez-obexd bluez-cups
dnf5 -y distro-sync --repo=fedora --repo=updates 'bluez*'
if rpm -q bluez | grep -q bazzite; then
      echo "ERROR: bluez is still bazzite's build after distro-sync"
      exit 1
fi

# Overrides ship via system_files overlay.
rm -f /usr/share/glib-2.0/schemas/zz0-*bazzite*.gschema.override 2>/dev/null || true

if [ -f /etc/xdg/mimeapps.list ]; then
      sed -i '/bazaar/d' /etc/xdg/mimeapps.list
fi

# Fedora defaults
sed -i -e '/^# VIM is more usable on deck/d' -e '\|^EDITOR=/usr/bin/vim$|d' \
      -e '/^# Disable Brew auto-update$/d' -e '/^HOMEBREW_NO_AUTO_UPDATE=/d' \
      -e '/^$/d' /etc/environment
rm -f /etc/profile.d/ms-edit-default-editor.sh

# Remove Bazzite verify
rm -f /etc/profile.d/verify_motd.sh
rm -f /usr/share/ublue-os/just/92-bazzite-verify.just
sed -i '\|/usr/share/ublue-os/just/92-bazzite-verify.just|d' /usr/share/ublue-os/justfile

# Strip Bazzite libvirt
rm -f /usr/lib/systemd/system/bazzite-libvirtd-setup.service
rm -f /usr/lib/tmpfiles.d/bazzite-libvirt.conf
rm -f /usr/share/ublue-os/just/84-bazzite-virt.just
sed -i '\|/usr/share/ublue-os/just/84-bazzite-virt.just|d' /usr/share/ublue-os/justfile

# Drops a just script with its comments, attributes, and aliases.
strip_justscript() {
      local file="/usr/share/ublue-os/just/$1" name="$2"
      grep -q "^${name}[ :]" "$file"
      awk -v name="$name" '
            function flush() { if (held != "") printf "%s", held; held = "" }
            skip && /^[^ \t]/ { skip = 0 }
            skip { next }
            $0 ~ "^alias [^ ]+ := " name "$" { flush(); next }
            $0 ~ "^" name "[ :]" { held = ""; skip = 1; next }
            /^(#|\[)/ { held = held $0 "\n"; next }
            { flush(); print }
            END { flush() }
      ' "$file" >"$file.new"
      mv "$file.new" "$file"
}

strip_justscript 10-update.just changelogs
strip_justscript 10-update.just changelogs-testing
strip_justscript 00-default.just toggle-user-motd
strip_justscript 80-bazzite.just bazzite-cli
strip_justscript 91-bazzite-decky.just get-decky-bazzite-buddy
strip_justscript 82-bazzite-apps.just resilio-sync
sed -i '\|docs.projectbluefin.io|d' /usr/share/ublue-os/justfile

rm -f /usr/share/ublue-os/just/94-bazzite-protonplus.just
sed -i '\|/usr/share/ublue-os/just/94-bazzite-protonplus.just|d' /usr/share/ublue-os/justfile

rm -f /usr/share/ublue-os/just/86-bazzite-windows.just
sed -i '\|/usr/share/ublue-os/just/86-bazzite-windows.just|d' /usr/share/ublue-os/justfile

# Deck only ujust scripts
if [[ "${IMAGE_VARIANT:-}" != deck* ]]; then
      rm -f /usr/share/ublue-os/just/95-bazzite-deck-session.just
      sed -i '\|/usr/share/ublue-os/just/95-bazzite-deck-session.just|d' /usr/share/ublue-os/justfile
fi

# Disable before rename; install-defenestra.sh re-enables the new names.
systemctl disable bazzite-flatpak-manager.service 2>/dev/null || true
systemctl disable bazzite-hardware-setup.service 2>/dev/null || true
systemctl --global disable bazzite-dynamic-fixes.service 2>/dev/null || true
systemctl --global disable bazzite-user-setup.service 2>/dev/null || true
systemctl disable bazzite-tdpfix.service 2>/dev/null || true
systemctl disable bazzite-autologin.service 2>/dev/null || true

echo ":: Bazzite stripping complete."
