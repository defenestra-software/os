#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -ouex pipefail

echo ":: Finalizing defenestraOS image..."

if [ -d /usr/share/glib-2.0/schemas ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas
fi

if [ -d /usr/share/icons/hicolor ]; then
    gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
fi

dconf update 2>/dev/null || true

# BIB validates GPG keys on every repo it reads, even disabled ones. Bazzite
# ships repos with stale keys (terra-mesa, rpmfusion wrong releasever) that
# fail BIB. Disable all non-Fedora repos; packages are already installed.
for repo in /etc/yum.repos.d/*.repo; do
    case "$(basename "$repo")" in
        fedora.repo|fedora-updates.repo|fedora-updates-archive.repo)
            ;;
        *)
            sed -i 's/^enabled=1/enabled=0/' "$repo" 2>/dev/null || true
            ;;
    esac
done

# Rebuild initramfs to embed plymouth branding.
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

dnf5 clean all

echo ":: Finalization complete."
