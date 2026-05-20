#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -ouex pipefail

# =============================================================================
# Install defenestraOS packages and overlay system files
#
# Bazzite base already handles gaming stack, services, kernel, drivers, etc.
# We only add what's unique to defenestraOS here.
# =============================================================================

echo ":: Installing defenestraOS packages..."

# -----------------------------------------------------------------------------
# defenestraOS COPR packages
# -----------------------------------------------------------------------------
dnf5 -y copr enable defenestra/defenestra
dnf5 -y install --refresh defenestra-arsenal defenestra-chassis
# TODO: Build these packages
# dnf5 -y install defenestra-store
dnf5 -y copr disable defenestra/defenestra

# GNOME extensions not in bazzite base
dnf5 -y install \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-light-style \
    gnome-shell-extension-drive-menu

# gnome-initial-setup - We need this for user setup and OEM installations
dnf5 -y install gnome-initial-setup

# Additional shells. bash stays default, fish inherited from bazzite.
# zsh = popular alternative.
dnf5 -y install zsh

# Homebrew: tarball already at /usr/share/homebrew.tar.zst (inherited from
# uBlue main via Bazzite). linuxbrew system user comes from sysusers.d drop-in
# (UID < 1000 hides it from gnome-initial-setup). Wrapper at /usr/bin/brew
# routes invocations through `sudo -u linuxbrew` so the prefix has one stable
# owner. Wheel-only via /etc/sudoers.d/defenestra-brew.
#
# Upstream brew-setup runs as first-login user (uid 1000); we mask their
# services so our defenestra-brew-* units own the lifecycle as `linuxbrew`.
# Upstream /etc/profile.d/brew.sh stays, it correctly sets PATH so
# brew-installed binaries work for all users.
# This works by actually making a system user the owner of brew
# and running all installs as that user `linuxbrew`
systemd-sysusers /ctx/system_files/usr/lib/sysusers.d/defenestra-linuxbrew.conf
systemctl mask brew-setup.service brew-update.service brew-update.timer \
    brew-upgrade.service brew-upgrade.timer 2>/dev/null || true

# Container toolbox
dnf5 -y install toolbox

# AMD GPU compute stack. Bazzite ships mesa-libOpenCL (Rusticl/Clover) which
# conflicts with ROCm's OpenCL ICD - remove first, then install ROCm.
# --setopt=install_weak_deps=False keeps the footprint to compute libs only,
# no test/debug recommends.
dnf5 -y remove mesa-libOpenCL
dnf5 -y --setopt=install_weak_deps=False install \
    rocm-hip \
    rocm-opencl \
    rocm-clinfo \
    rocm-smi

# Low-level dev/tracing tools
dnf5 -y install \
    bpftrace \
    bcc \
    flatpak-builder \
    waypipe \
    git-subtree \
    iotop \
    trace-cmd

# Incus + agent. Bazzite already ships lxc; incus is the actively-maintained
# fork of LXD that drives modern system container management. Pair completes
# the lxc stack already present.
dnf5 -y install \
    incus \
    incus-agent

# sys tray libraries
dnf5 -y install \
    libappindicator-gtk3 \
    libayatana-appindicator-gtk3

# Cockpit web admin
dnf5 -y install \
    cockpit \
    cockpit-ostree

# Fonts.
dnf5 -y install \
    adwaita-fonts-all \
    jetbrains-mono-fonts-all \
    opendyslexic-fonts \
    google-roboto-fonts \
    google-roboto-condensed-fonts \
    google-roboto-mono-fonts \
    google-roboto-slab-fonts

# Docker CE from upstream Docker
docker_pkgs=(
    containerd.io
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
)
dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
dnf5 config-manager setopt docker-ce-stable.enabled=0
dnf5 -y install --enable-repo="docker-ce-stable" "${docker_pkgs[@]}"

# iptable_nat for docker-in-docker (devcontainer compat)
# https://github.com/ublue-os/bluefin/issues/2365
mkdir -p /etc/modules-load.d
echo iptable_nat > /etc/modules-load.d/defenestra-docker.conf

# Nix package manager - F44 ships official RPMs.
# nix-daemon sub-package provides systemd units (multi-user mode).
# /var/nix holds the store; bound onto /nix via nix.mount unit at boot.

dnf5 -y install nix nix-daemon
mkdir -p /usr/share/factory/var/nix
cp -a /nix/. /usr/share/factory/var/nix/
rm -rf /nix/*

# SELinux: Fedora ships no policy for /nix paths. Use Determinate Systems'
# nix.pp policy module (vendored at system_files/usr/share/selinux/packages/
# defenestra/nix.pp) - provides fcontext rules for store/socket/profiles AND
# the `allow init_t default_t:lnk_file read` rule that fcontext alone misses
# (init_t needs to traverse symlinks in daemon socket activation path).
# Source .te/.fc shipped alongside .pp for audit.
# Load from /ctx (build context bind) since system_files overlay runs later.
semodule -i /ctx/system_files/usr/share/selinux/packages/defenestra/nix.pp
# Relabel the factory-staged store. nix.fc rules are keyed on /nix paths, so
# the authoritative store relabel happens on first boot once /var/nix is
# bind-mounted at /nix (see defenestra-nix-store-relabel.service). This
# build-time pass just clears RPM-inherited contexts on the factory copy.
restorecon -RF /usr/share/factory/var/nix

# Enterprise features from Bluefin
dnf5 -y install \
    sssd \
    sssd-dbus \
    sssd-idp \
    sssd-nfs-idmap \
    sssd-passkey \
    sssd-tools \
    adcli \
    realmd \
    krb5-workstation \
    oddjob \
    oddjob-mkhomedir \
    openldap-clients \
    samba \
    samba-common-tools \
    samba-dcerpc \
    samba-ldb-ldap-modules \
    samba-winbind-clients \
    samba-winbind-modules \
    autofs \
    davfs2 \
    nfs4-acl-tools

# Fix SSSD binary capabilities - Bazzite's build strips file caps from
# SSSD helper binaries, breaking LDAP/Kerberos auth on atomic desktops.
# Kinoite with same SSSD version works fine, so this is a build artifact issue.
# See: https://github.com/ublue-os/bazzite/issues/1818
if [ -f /usr/libexec/sssd/krb5_child ]; then
    setcap cap_chown,cap_dac_override,cap_setgid,cap_setuid=ep /usr/libexec/sssd/krb5_child
    setcap cap_chown,cap_dac_override,cap_setgid,cap_setuid=ep /usr/libexec/sssd/ldap_child
    setcap cap_dac_read_search=p /usr/libexec/sssd/sssd_pam
    echo ":: SSSD binary capabilities restored."
fi

# -----------------------------------------------------------------------------
# Flatpak remote - defenestra repo
# -----------------------------------------------------------------------------

flatpak remote-add --if-not-exists --from defenestra \
    https://my.defenestra.io/downloads/defenestra.flatpakrepo 2>/dev/null || true

# -----------------------------------------------------------------------------
# Overlay system files
#
# Only defenestraOS-specific overlays:
#   usr/share/glib-2.0/schemas/        - Our GSchema overrides
#   usr/share/gnome-shell/extensions/   - Our bundled GNOME extensions
#   usr/share/backgrounds/              - Our wallpapers
#   etc/dconf/db/distro.d/              - Our dconf database
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

# No Startup Overview: defenestra in-tree, JS only, no schemas
if [ -d "${BUNDLED_EXT_SRC}/no-startup-overview@defenestra.io" ]; then
    cp -r "${BUNDLED_EXT_SRC}/no-startup-overview@defenestra.io" "${BUNDLED_EXT_DST}/"
fi

# Show Logout: defenestra in-tree, JS only, no schemas
if [ -d "${BUNDLED_EXT_SRC}/show-logout@defenestra.io" ]; then
    cp -r "${BUNDLED_EXT_SRC}/show-logout@defenestra.io" "${BUNDLED_EXT_DST}/"
fi

# Clipboard Indicator - straightforward copy
if [ -d "${BUNDLED_EXT_SRC}/clipboard-indicator@tudmotu.com" ]; then
    cp -r "${BUNDLED_EXT_SRC}/clipboard-indicator@tudmotu.com" "${BUNDLED_EXT_DST}/"
    if [ -d "${BUNDLED_EXT_DST}/clipboard-indicator@tudmotu.com/schemas" ]; then
        glib-compile-schemas "${BUNDLED_EXT_DST}/clipboard-indicator@tudmotu.com/schemas"
    fi
fi

# ArcMenu - flatten src/ to root, compile resources
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

# Desktop Icons NG (DING) - root layout, compile schemas
if [ -d "${BUNDLED_EXT_SRC}/ding@rastersoft.com" ]; then
    DING_SRC="${BUNDLED_EXT_SRC}/ding@rastersoft.com"
    DING_DST="${BUNDLED_EXT_DST}/ding@rastersoft.com"
    mkdir -p "${DING_DST}"
    rsync -a \
        --exclude='.git' --exclude='debian' --exclude='meson.build' \
        --exclude='meson_post_install.py' --exclude='*.sh' --exclude='kill.py' \
        --exclude='HISTORY.md' --exclude='README.md' --exclude='apparmor' \
        "${DING_SRC}/" "${DING_DST}/"
    glib-compile-schemas "${DING_DST}/schemas"
fi

# Tiling Assistant - extension lives in same-named subdir
if [ -d "${BUNDLED_EXT_SRC}/tiling-assistant@leleat-on-github/tiling-assistant@leleat-on-github" ]; then
    TA_SRC="${BUNDLED_EXT_SRC}/tiling-assistant@leleat-on-github/tiling-assistant@leleat-on-github"
    TA_DST="${BUNDLED_EXT_DST}/tiling-assistant@leleat-on-github"
    mkdir -p "${TA_DST}"
    cp -r "${TA_SRC}"/. "${TA_DST}/"
    glib-compile-schemas "${TA_DST}/schemas"
fi

# Alphabetical App Grid - extension lives in extension/ subdir
if [ -d "${BUNDLED_EXT_SRC}/AlphabeticalAppGrid@stuarthayhurst/extension" ]; then
    AAG_SRC="${BUNDLED_EXT_SRC}/AlphabeticalAppGrid@stuarthayhurst/extension"
    AAG_DST="${BUNDLED_EXT_DST}/AlphabeticalAppGrid@stuarthayhurst"
    mkdir -p "${AAG_DST}"
    cp -r "${AAG_SRC}"/. "${AAG_DST}/"
    glib-compile-schemas "${AAG_DST}/schemas"
fi

dnf5 -y remove glib2-devel

# Tiling Shell - prebuilt zip from upstream releases (TypeScript/esbuild
# build output, ships compiled gschemas + gresource + .mo). Avoids pulling
# nodejs/npm into the image build.
command -v unzip >/dev/null 2>&1 || dnf5 -y install unzip
TILINGSHELL_VERSION="17.3"
TILINGSHELL_SHA256="63ab8230b62c1a888d5af40e47aef0676e5e99ac367e35f51a797fe3b9a79370"
TILINGSHELL_URL="https://github.com/domferr/tilingshell/releases/download/${TILINGSHELL_VERSION}/tilingshell%40ferrarodomenico.com.zip"
TILINGSHELL_DST="${BUNDLED_EXT_DST}/tilingshell@ferrarodomenico.com"
TILINGSHELL_TMP="$(mktemp -d)"
curl -fsSL -o "${TILINGSHELL_TMP}/ts.zip" "${TILINGSHELL_URL}"
echo "${TILINGSHELL_SHA256}  ${TILINGSHELL_TMP}/ts.zip" | sha256sum -c -
mkdir -p "${TILINGSHELL_DST}"
unzip -q -o "${TILINGSHELL_TMP}/ts.zip" -d "${TILINGSHELL_DST}"
rm -rf "${TILINGSHELL_TMP}"

# -----------------------------------------------------------------------------
# Re-enable renamed services
#
# strip-bazzite.sh disabled the bazzite-* originals.
# rename-scripts.sh renamed them to defenestra-*.
# We re-enable them here under their new names.
# -----------------------------------------------------------------------------

systemctl enable defenestra-nix-reseed.service 2>/dev/null || true
systemctl enable nix.mount 2>/dev/null || true
systemctl enable defenestra-nix-store-relabel.service 2>/dev/null || true
systemctl enable nix-daemon.socket 2>/dev/null || true
# Mirror Nix profile XDG entries into /usr/local/share + ~/.local/share so
# GNOME Shell shows newly installed apps live, no relog. User unit enabled
# via /usr/lib/systemd/user-preset/90-defenestra.preset on first session.
systemctl enable defenestra-nix-xdg-sync.path 2>/dev/null || true
systemctl --global enable defenestra-nix-xdg-sync.path 2>/dev/null || true

# Docker: socket-activated, daemon starts on first use.
systemctl enable docker.socket 2>/dev/null || true

# Homebrew: first-boot extraction + daily update timer.
systemctl enable defenestra-brew-setup.service 2>/dev/null || true
systemctl enable defenestra-brew-update.timer 2>/dev/null || true

systemctl enable defenestra-flatpak-manager.service 2>/dev/null || true
systemctl enable defenestra-hardware-setup.service 2>/dev/null || true
systemctl enable defenestra-libvirtd-setup.service 2>/dev/null || true
systemctl --global enable defenestra-dynamic-fixes.service 2>/dev/null || true
systemctl --global enable defenestra-user-setup.service 2>/dev/null || true

# Handheld (only exists on deck images)
systemctl enable defenestra-tdpfix.service 2>/dev/null || true
systemctl enable defenestra-autologin.service 2>/dev/null || true

echo ":: defenestraOS packages installed."
