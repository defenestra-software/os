#!/bin/bash
set -ouex pipefail

# =============================================================================
# DefenestraOS — finalize image
# =============================================================================

echo ":: Finalizing DefenestraOS image..."

# Compile GSchema overrides
if [ -d /usr/share/glib-2.0/schemas ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas
fi

# Update icon cache
if [ -d /usr/share/icons/hicolor ]; then
    gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
fi

# Update dconf database
dconf update 2>/dev/null || true

# Clean package cache
dnf5 clean all

echo ":: Finalization complete."
