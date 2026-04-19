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

# TODO: Enable when COPR repo is set up
# dnf5 -y copr enable defenestra/defenestra
# dnf5 -y install defenestra-branding
# dnf5 -y install defenestra-welcome
# dnf5 -y install defenestra-store
# dnf5 -y copr disable defenestra/defenestra

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
    rsync -av /ctx/system_files/ /
    echo ":: System files overlaid."
else
    echo ":: No system_files to overlay (skeleton build)."
fi

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
