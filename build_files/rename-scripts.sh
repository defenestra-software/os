#!/bin/bash
set -ouex pipefail

# =============================================================================
# Rename bazzite-* scripts, services, and configs → defenestra-*
#
# This renames files AND updates internal references so everything still works.
# =============================================================================

echo ":: Renaming bazzite scripts to defenestra..."

# -----------------------------------------------------------------------------
# Helper: rename a file and update all references in known locations
# -----------------------------------------------------------------------------

rename_file() {
    local old="$1"
    local new="$2"

    if [ -f "$old" ]; then
        mv "$old" "$new"
        echo "  Renamed: $(basename "$old") → $(basename "$new")"
    fi
}

# -----------------------------------------------------------------------------
# Scripts — /usr/libexec/
# -----------------------------------------------------------------------------

rename_file /usr/libexec/bazzite-user-setup           /usr/libexec/defenestra-user-setup
rename_file /usr/libexec/bazzite-privileged-user-setup /usr/libexec/defenestra-privileged-user-setup
rename_file /usr/libexec/bazzite-hardware-setup        /usr/libexec/defenestra-hardware-setup
rename_file /usr/libexec/bazzite-dynamic-fixes         /usr/libexec/defenestra-dynamic-fixes
rename_file /usr/libexec/bazzite-flatpak-manager       /usr/libexec/defenestra-flatpak-manager
rename_file /usr/libexec/bazzite-boot-remount          /usr/libexec/defenestra-boot-remount
rename_file /usr/libexec/bazzite-bling-fastfetch       /usr/libexec/defenestra-bling-fastfetch
rename_file /usr/libexec/bazzite-powersave             /usr/libexec/defenestra-powersave
rename_file /usr/libexec/bazzite-snapper-config        /usr/libexec/defenestra-snapper-config
rename_file /usr/libexec/bazzite-fetch-image           /usr/libexec/defenestra-fetch-image
# Handheld
rename_file /usr/libexec/bazzite-tdpfix                /usr/libexec/defenestra-tdpfix
rename_file /usr/libexec/bazzite-autologin             /usr/libexec/defenestra-autologin

# -----------------------------------------------------------------------------
# Scripts — /usr/bin/
# -----------------------------------------------------------------------------

rename_file /usr/bin/bazzite-steam                     /usr/bin/defenestra-steam
rename_file /usr/bin/bazzite-steam-bpm                 /usr/bin/defenestra-steam-bpm
rename_file /usr/bin/bazzite-steam-brand               /usr/bin/defenestra-steam-brand
rename_file /usr/bin/bazzite-rollback-helper            /usr/bin/defenestra-rollback-helper
rename_file /usr/bin/bazzite-desktop-bootstrap         /usr/bin/defenestra-desktop-bootstrap

# Update bruh alias if it exists
if [ -f /usr/bin/bruh ]; then
    sed -i 's/bazzite-rollback-helper/defenestra-rollback-helper/g' /usr/bin/bruh
fi

# -----------------------------------------------------------------------------
# Systemd services
# -----------------------------------------------------------------------------

rename_file /usr/lib/systemd/system/bazzite-hardware-setup.service   /usr/lib/systemd/system/defenestra-hardware-setup.service
rename_file /usr/lib/systemd/system/bazzite-flatpak-manager.service  /usr/lib/systemd/system/defenestra-flatpak-manager.service
rename_file /usr/lib/systemd/system/bazzite-libvirtd-setup.service   /usr/lib/systemd/system/defenestra-libvirtd-setup.service
rename_file /usr/lib/systemd/user/bazzite-dynamic-fixes.service      /usr/lib/systemd/user/defenestra-dynamic-fixes.service
rename_file /usr/lib/systemd/user/bazzite-user-setup.service         /usr/lib/systemd/user/defenestra-user-setup.service
# Handheld
rename_file /usr/lib/systemd/system/bazzite-tdpfix.service           /usr/lib/systemd/system/defenestra-tdpfix.service
rename_file /usr/lib/systemd/system/bazzite-autologin.service        /usr/lib/systemd/system/defenestra-autologin.service

# -----------------------------------------------------------------------------
# Polkit policies
# -----------------------------------------------------------------------------

rename_file /usr/share/polkit-1/actions/org.bazzite.privileged.user.setup.policy \
            /usr/share/polkit-1/actions/org.defenestra.privileged.user.setup.policy
rename_file /usr/share/polkit-1/actions/org.bazzite.waydroid.policy \
            /usr/share/polkit-1/actions/org.defenestra.waydroid.policy
rename_file /usr/share/polkit-1/actions/org.bazzite.hhd.policy \
            /usr/share/polkit-1/actions/org.defenestra.hhd.policy
rename_file /usr/share/polkit-1/actions/org.bazzite.rebase.policy \
            /usr/share/polkit-1/actions/org.defenestra.rebase.policy
rename_file /usr/share/polkit-1/rules.d/bazzite-autologin.rules \
            /usr/share/polkit-1/rules.d/defenestra-autologin.rules

# -----------------------------------------------------------------------------
# Just recipes
# -----------------------------------------------------------------------------

for f in /usr/share/ublue-os/just/*bazzite*.just; do
    [ -f "$f" ] || continue
    newname="${f//bazzite/defenestra}"
    mv "$f" "$newname"
    echo "  Renamed: $(basename "$f") → $(basename "$newname")"
done

# -----------------------------------------------------------------------------
# Firefox configs
# -----------------------------------------------------------------------------

rename_file /usr/share/ublue-os/firefox-config/01-bazzite-global.js  /usr/share/ublue-os/firefox-config/01-defenestra-global.js
rename_file /usr/share/ublue-os/firefox-config/02-bazzite-nvidia.js  /usr/share/ublue-os/firefox-config/02-defenestra-nvidia.js
rename_file /usr/share/ublue-os/firefox-config/03-bazzite-gnome.js   /usr/share/ublue-os/firefox-config/03-defenestra-gnome.js

# -----------------------------------------------------------------------------
# Profile scripts
# -----------------------------------------------------------------------------

rename_file /etc/profile.d/bazzite-neofetch.sh /etc/profile.d/defenestra-fastfetch.sh

# Fish
rename_file /usr/share/fish/vendor_conf.d/bazzite-neofetch.fish /usr/share/fish/vendor_conf.d/defenestra-fastfetch.fish

# -----------------------------------------------------------------------------
# Desktop files
# -----------------------------------------------------------------------------

rename_file /usr/share/applications/bazzite-steam-bpm.desktop /usr/share/applications/defenestra-steam-bpm.desktop
# Handheld
rename_file /etc/xdg/autostart/bazzite-desktop-bootstrap.desktop /etc/xdg/autostart/defenestra-desktop-bootstrap.desktop

# -----------------------------------------------------------------------------
# Homebrew config
# -----------------------------------------------------------------------------

rename_file /usr/share/ublue-os/homebrew/bazzite-cli.Brewfile /usr/share/ublue-os/homebrew/defenestra-cli.Brewfile

# -----------------------------------------------------------------------------
# dconf database files
# -----------------------------------------------------------------------------

for f in /etc/dconf/db/distro.d/*bazzite*; do
    [ -f "$f" ] || continue
    newname="${f//bazzite/defenestra}"
    mv "$f" "$newname"
    echo "  Renamed: $(basename "$f") → $(basename "$newname")"
done

for f in /etc/dconf/db/distro.d/locks/*bazzite*; do
    [ -f "$f" ] || continue
    newname="${f//bazzite/defenestra}"
    mv "$f" "$newname"
    echo "  Renamed: $(basename "$f") → $(basename "$newname")"
done

# -----------------------------------------------------------------------------
# Tuned profiles (optional — cosmetic rename)
# -----------------------------------------------------------------------------

for d in /usr/lib/tuned/profiles/*-bazzite*; do
    [ -d "$d" ] || continue
    newname="${d//bazzite/defenestra}"
    mv "$d" "$newname"
    echo "  Renamed: $(basename "$d") → $(basename "$newname")"
done

# -----------------------------------------------------------------------------
# Bulk sed: update internal references in all renamed files
#
# This catches ExecStart= paths, script cross-references, action IDs, etc.
# We target specific directories to avoid touching binary files.
# -----------------------------------------------------------------------------

echo ":: Updating internal references (bazzite → defenestra)..."

sed_dirs=(
    /usr/libexec
    /usr/bin
    /usr/lib/systemd
    /usr/share/polkit-1
    /usr/share/ublue-os/just
    /usr/share/ublue-os/firefox-config
    /usr/share/applications
    /etc/xdg/autostart
    /etc/dconf/db
    /etc/profile.d
    /usr/share/fish
    /usr/lib/tuned
    /usr/share/ublue-os/homebrew
)

for dir in "${sed_dirs[@]}"; do
    [ -d "$dir" ] || continue
    find "$dir" -type f \( -name '*.sh' -o -name '*.service' -o -name '*.policy' \
        -o -name '*.rules' -o -name '*.just' -o -name '*.js' -o -name '*.desktop' \
        -o -name '*.fish' -o -name '*.conf' -o -name '*.toml' -o -name '*.Brewfile' \
        -o -name 'defenestra-*' -o -name '*-defenestra-*' \) \
        -exec sed -i \
            -e 's/bazzite-steam-bpm/defenestra-steam-bpm/g' \
            -e 's/bazzite-steam-brand/defenestra-steam-brand/g' \
            -e 's/bazzite-steam/defenestra-steam/g' \
            -e 's/bazzite-rollback-helper/defenestra-rollback-helper/g' \
            -e 's/bazzite-desktop-bootstrap/defenestra-desktop-bootstrap/g' \
            -e 's/bazzite-user-setup/defenestra-user-setup/g' \
            -e 's/bazzite-privileged-user-setup/defenestra-privileged-user-setup/g' \
            -e 's/bazzite-hardware-setup/defenestra-hardware-setup/g' \
            -e 's/bazzite-dynamic-fixes/defenestra-dynamic-fixes/g' \
            -e 's/bazzite-flatpak-manager/defenestra-flatpak-manager/g' \
            -e 's/bazzite-boot-remount/defenestra-boot-remount/g' \
            -e 's/bazzite-bling-fastfetch/defenestra-bling-fastfetch/g' \
            -e 's/bazzite-powersave/defenestra-powersave/g' \
            -e 's/bazzite-snapper-config/defenestra-snapper-config/g' \
            -e 's/bazzite-fetch-image/defenestra-fetch-image/g' \
            -e 's/bazzite-tdpfix/defenestra-tdpfix/g' \
            -e 's/bazzite-autologin/defenestra-autologin/g' \
            -e 's/bazzite-libvirtd-setup/defenestra-libvirtd-setup/g' \
            -e 's/org\.bazzite\./org.defenestra./g' \
            -e 's/bazzite-neofetch/defenestra-fastfetch/g' \
            -e 's/bazzite-cli\.Brewfile/defenestra-cli.Brewfile/g' \
            {} +
done

# Update polkit XML content (vendor name, URLs)
for f in /usr/share/polkit-1/actions/org.defenestra.*.policy; do
    [ -f "$f" ] || continue
    sed -i \
        -e 's|Bazzite|DefenestraOS|g' \
        -e 's|bazzite\.gg|defenestra.io|g' \
        "$f"
done

echo ":: Rename complete."
