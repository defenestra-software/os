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

# Disable all non-Fedora repos in the final image.
# BIB (bootc-image-builder) reads repo configs and validates GPG keys even for
# disabled repos. Several bazzite repos have stale/missing GPG keys that cause
# BIB to fail (terra-mesa, rpmfusion with wrong releasever, etc).
# These repos aren't needed post-build — packages are already installed.
for repo in /etc/yum.repos.d/*.repo; do
    case "$(basename "$repo")" in
        fedora.repo|fedora-updates.repo|fedora-updates-archive.repo)
            # Keep core Fedora repos enabled
            ;;
        *)
            sed -i 's/^enabled=1/enabled=0/' "$repo" 2>/dev/null || true
            ;;
    esac
done

# Rebuild initramfs — embeds our plymouth branding into boot image
QUALIFIED_KERNEL="$(dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel)"
echo ":: Rebuilding initramfs for kernel ${QUALIFIED_KERNEL}..."
/usr/bin/dracut \
    --no-hostonly \
    --kver "$QUALIFIED_KERNEL" \
    --reproducible \
    --zstd \
    --add ostree \
    --add fido2 \
    -v -f \
    "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"

# Clean package cache
dnf5 clean all

echo ":: Finalization complete."
