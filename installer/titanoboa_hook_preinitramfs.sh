#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Live ISO: uses stock Fedora kernel (secure boot).
# Installed system keeps bazzite's kernel

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

# live session needs nvidia-gpu-firmware
dnf install -yq nvidia-gpu-firmware || :
dnf clean all -yq
