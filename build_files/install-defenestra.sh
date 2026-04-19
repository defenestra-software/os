#!/bin/bash
set -ouex pipefail

# =============================================================================
# Install DefenestraOS packages and overlay system files
#
# Bazzite base already handles gaming stack, services, kernel, drivers, etc.
# We only add what's unique to DefenestraOS here.
# =============================================================================

echo ":: Installing DefenestraOS packages..."

# -----------------------------------------------------------------------------
# DefenestraOS COPR packages (when available)
# -----------------------------------------------------------------------------

dnf5 -y copr enable defenestra/defenestra
dnf5 -y install --allowerasing --refresh defenestra-branding
# TODO: Build these packages
# dnf5 -y install defenestra-welcome
# dnf5 -y install defenestra-store
dnf5 -y copr disable defenestra/defenestra

# gnome-initial-setup — bazzite doesn't include it (uses their own portal).
# We stripped bazzite-portal, so we need this for first-boot user creation.
dnf5 -y install gnome-initial-setup

# -----------------------------------------------------------------------------
# Flatpak remote — defenestra repo
# -----------------------------------------------------------------------------

flatpak remote-add --if-not-exists --from defenestra \
    https://my.defenestra.io/downloads/defenestra.flatpakrepo 2>/dev/null || true

# -----------------------------------------------------------------------------
# Overlay system files
#
# Only DefenestraOS-specific overlays:
#   usr/share/glib-2.0/schemas/        — Our GSchema overrides
#   usr/share/gnome-shell/extensions/   — Our bundled GNOME extensions
#   usr/share/backgrounds/              — Our wallpapers
#   etc/dconf/db/distro.d/              — Our dconf database
# -----------------------------------------------------------------------------

if [ -d /ctx/system_files ] && [ "$(ls -A /ctx/system_files 2>/dev/null)" ]; then
    # Overlay everything EXCEPT extensions (handled below) and nvidia (conditional)
    rsync -av --exclude='usr/share/gnome-shell/extensions' --exclude='nvidia' /ctx/system_files/ /
    echo ":: System files overlaid."

    # Nvidia-specific overlays (only for nvidia variants)
    if [[ "${IMAGE_VARIANT:-}" == *nvidia* ]] && [ -d /ctx/system_files/nvidia ]; then
        rsync -av /ctx/system_files/nvidia/ /
        echo ":: Nvidia system files overlaid."
    fi
else
    echo ":: No system_files to overlay (skeleton build)."
fi

# -----------------------------------------------------------------------------
# Bundled GNOME extensions (from submodules)
# -----------------------------------------------------------------------------

BUNDLED_EXT_SRC="/ctx/system_files/usr/share/gnome-shell/extensions"
BUNDLED_EXT_DST="/usr/share/gnome-shell/extensions"

dnf5 -y install glib2-devel

# Clipboard Indicator — straightforward copy
if [ -d "${BUNDLED_EXT_SRC}/clipboard-indicator@tudmotu.com" ]; then
    cp -r "${BUNDLED_EXT_SRC}/clipboard-indicator@tudmotu.com" "${BUNDLED_EXT_DST}/"
    if [ -d "${BUNDLED_EXT_DST}/clipboard-indicator@tudmotu.com/schemas" ]; then
        glib-compile-schemas "${BUNDLED_EXT_DST}/clipboard-indicator@tudmotu.com/schemas"
    fi
fi

# ArcMenu — flatten src/ to root, compile resources
if [ -d "${BUNDLED_EXT_SRC}/arcmenu@arcmenu.com" ]; then
    ARCMENU_SRC="${BUNDLED_EXT_SRC}/arcmenu@arcmenu.com"
    ARCMENU_DST="${BUNDLED_EXT_DST}/arcmenu@arcmenu.com"
    mkdir -p "${ARCMENU_DST}/data"
    cp -r "${ARCMENU_SRC}/src"/* "${ARCMENU_DST}/"
    cp "${ARCMENU_SRC}/metadata.json" "${ARCMENU_DST}/"
    cp "${ARCMENU_SRC}/LICENSE" "${ARCMENU_DST}/"
    cp -r "${ARCMENU_SRC}/schemas" "${ARCMENU_DST}/"
    cp -r "${ARCMENU_SRC}/data/icons" "${ARCMENU_DST}/data/"
    cp "${ARCMENU_SRC}/data/resources.gresource.xml" "${ARCMENU_DST}/data/"
    glib-compile-resources --sourcedir="${ARCMENU_DST}/data" "${ARCMENU_DST}/data/resources.gresource.xml"
    glib-compile-schemas "${ARCMENU_DST}/schemas"
fi

dnf5 -y remove glib2-devel

# -----------------------------------------------------------------------------
# Re-enable renamed services
#
# strip-bazzite.sh disabled the bazzite-* originals.
# rename-scripts.sh renamed them to defenestra-*.
# We re-enable them here under their new names.
# -----------------------------------------------------------------------------

systemctl enable defenestra-flatpak-manager.service 2>/dev/null || true
systemctl enable defenestra-hardware-setup.service 2>/dev/null || true
systemctl enable defenestra-libvirtd-setup.service 2>/dev/null || true
systemctl --global enable defenestra-dynamic-fixes.service 2>/dev/null || true
systemctl --global enable defenestra-user-setup.service 2>/dev/null || true

# Handheld (only exists on deck images)
systemctl enable defenestra-tdpfix.service 2>/dev/null || true
systemctl enable defenestra-autologin.service 2>/dev/null || true

echo ":: DefenestraOS packages installed."
