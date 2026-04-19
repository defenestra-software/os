#!/bin/bash
set -ouex pipefail

# =============================================================================
# Strip Bazzite identity from base image
#
# Removes branding, onboarding, app store, and announcement system.
# Does NOT remove hardware support, gaming stack, or system utilities.
# See STRIP-GUIDE.md for full audit of what's kept vs stripped.
# =============================================================================

echo ":: Stripping bazzite branding and onboarding..."

# -----------------------------------------------------------------------------
# RPMs — clean package removal
# -----------------------------------------------------------------------------

# Verified against live bazzite 43.20260403.0 (Silverblue)
dnf5 remove -y --noautoremove bazaar           # Bazzite app store
dnf5 remove -y --noautoremove bazzite-portal   # Bazzite welcome/portal app

# -----------------------------------------------------------------------------
# Branding assets
# -----------------------------------------------------------------------------

# Bazzite logos, boot animations, branding directory
rm -rf /usr/share/ublue-os/bazzite/

# Bazzite icons (all sizes)
find /usr/share/icons/hicolor -name 'bazzite-*' -delete 2>/dev/null || true

# Distributor logos (replaced by branding RPM)
# NOTE: Only delete if branding RPM will provide replacements
# rm -f /usr/share/icons/hicolor/scalable/places/distributor-logo.svg
# rm -f /usr/share/icons/hicolor/scalable/places/distributor-logo-white.svg

# Fedora branding overrides (replaced by branding RPM)
# rm -f /usr/share/pixmaps/fedora-*
# rm -f /usr/share/pixmaps/system-logo-white.png
# rm -f /usr/share/pixmaps/bootloader/fedora.icns
# rm -f /etc/favicon.png

# -----------------------------------------------------------------------------
# Onboarding & announcements
# -----------------------------------------------------------------------------

rm -f /etc/xdg/autostart/bazzite-announcement.desktop
rm -f /usr/libexec/bazzite-announcement
rm -rf /usr/share/ublue-os/announcements/
rm -rf /usr/share/yafti/

# -----------------------------------------------------------------------------
# Bazzite documentation & community links
# -----------------------------------------------------------------------------

rm -f /usr/share/applications/bazzite-documentation.desktop
rm -f /usr/share/applications/discourse.desktop
rm -f /usr/share/applications/system-update.desktop
rm -f /usr/share/applications/bbrew.desktop

# -----------------------------------------------------------------------------
# Bazaar app store assets (RPM handles binary, these are leftover configs)
# -----------------------------------------------------------------------------

rm -rf /usr/share/ublue-os/bazaar/

# -----------------------------------------------------------------------------
# MOTD (we'll provide our own or skip)
# -----------------------------------------------------------------------------

rm -rf /usr/share/ublue-os/motd/

# -----------------------------------------------------------------------------
# Bazzite-specific dconf branding (deck logo menu)
# -----------------------------------------------------------------------------

rm -f /etc/dconf/db/distro.d/10-bazzite-deck-silverblue-logomenu 2>/dev/null || true

# -----------------------------------------------------------------------------
# Bazzite-specific GSchema overrides
# We remove these and provide our own via system_files overlay
# -----------------------------------------------------------------------------

rm -f /usr/share/glib-2.0/schemas/zz0-*bazzite*.gschema.override 2>/dev/null || true

# -----------------------------------------------------------------------------
# Update mimeapps to remove bazaar as default handler
# -----------------------------------------------------------------------------

if [ -f /etc/xdg/mimeapps.list ]; then
    sed -i '/bazaar/d' /etc/xdg/mimeapps.list
fi

# -----------------------------------------------------------------------------
# Disable bazzite-specific systemd services (before rename script renames them)
# We re-enable under new names in install-defenestra.sh
# -----------------------------------------------------------------------------

# These will be renamed and re-enabled, but we disable originals first
# to avoid conflicts during the rename step
systemctl disable bazzite-flatpak-manager.service 2>/dev/null || true
systemctl disable bazzite-hardware-setup.service 2>/dev/null || true
systemctl disable bazzite-libvirtd-setup.service 2>/dev/null || true
systemctl --global disable bazzite-dynamic-fixes.service 2>/dev/null || true
systemctl --global disable bazzite-user-setup.service 2>/dev/null || true
systemctl disable bazzite-tdpfix.service 2>/dev/null || true
systemctl disable bazzite-autologin.service 2>/dev/null || true

echo ":: Bazzite stripping complete."
