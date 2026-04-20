#!/usr/bin/env bash
# Swap bazzite kernel with vanilla Fedora kernel for secure boot compatibility
# in the live ISO. The installed system will use the bazzite kernel.

set -exo pipefail

kernel_pkgs=(
    kernel
    kernel-core
    kernel-devel
    kernel-devel-matched
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
)
dnf -y versionlock delete "${kernel_pkgs[@]}"
dnf --setopt=protect_running_kernel=False -y remove "${kernel_pkgs[@]}"
(cd /usr/lib/modules && rm -rf -- ./*)
dnf -y --repo fedora,updates --setopt=tsflags=noscripts install kernel kernel-core
kernel=$(find /usr/lib/modules -maxdepth 1 -type d -printf '%P\n' | grep .)
depmod "$kernel"

# Include nvidia-gpu-firmware for broad hardware support in live session
dnf install -yq nvidia-gpu-firmware || :
dnf clean all -yq
