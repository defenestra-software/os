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
# defenestraOS COPR packages (when available)
# -----------------------------------------------------------------------------

dnf5 -y copr enable defenestra/defenestra
# fedora-logos is a defenestra fork (42.0.1-200.defenestra) that replaces the
# upstream 42.0.1-2.fc43 - ships our pixmap/favicon/plymouth overrides baked in.
# defenestra-branding ships defenestra-specific icons that don't collide with
# fedora-logos paths.
dnf5 -y upgrade --refresh fedora-logos
dnf5 -y install --refresh defenestra-branding

# GNOME extensions not in bazzite base
dnf5 -y install \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-light-style
# TODO: Build these packages
# dnf5 -y install defenestra-welcome
# dnf5 -y install defenestra-store
dnf5 -y copr disable defenestra/defenestra

# gnome-initial-setup - bazzite doesn't include it (uses their own portal).
# We stripped bazzite-portal, so we need this for first-boot user creation.
dnf5 -y install gnome-initial-setup

# Additional shells. bash stays default, fish inherited from bazzite.
# zsh = popular alternative. nushell available via nix (`nix profile install nixpkgs#nushell`).
dnf5 -y install zsh

# Container tooling: toolbox (Fedora's, "Toolbx") complements distrobox
# (already in bazzite). distrobox = arch/deb/rpm/snap user containers,
# toolbox = Fedora-only seamless dev container. Both available, user picks.
dnf5 -y install toolbox

# Docker CE from upstream Docker Inc. Pattern from bazzite-dx: repo added
# but disabled, install with --enable-repo for this transaction only.
# Socket-activated: zero runtime cost until first `docker` invocation.
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
# Seed /var/nix from RPM-shipped /nix so bind mount doesn't hide store/db.
dnf5 -y install nix nix-daemon
mkdir -p /var/nix
cp -a /nix/. /var/nix/
rm -rf /nix/*

# SELinux: Fedora ships no policy for /nix paths. Use Determinate Systems'
# nix.pp policy module (vendored at system_files/usr/share/selinux/packages/
# defenestra/nix.pp) - provides fcontext rules for store/socket/profiles AND
# the `allow init_t default_t:lnk_file read` rule that fcontext alone misses
# (init_t needs to traverse symlinks in daemon socket activation path).
# Source .te/.fc shipped alongside .pp for audit.
# Load from /ctx (build context bind) since system_files overlay runs later.
semodule -i /ctx/system_files/usr/share/selinux/packages/defenestra/nix.pp
restorecon -RF /var/nix

# Enterprise / network authentication & file sharing
# Bazzite is gaming-focused and ships minimal enterprise support.
# Bluefin is workstation-focused and ships a partial AD/Samba stack.
# We add the FULL enterprise stack - gaming from Bazzite, enterprise from us.
# Enables GNOME Initial Setup "Enterprise Login" page (requires realmd).
# See: https://github.com/ublue-os/main/issues/1378
#
# SSSD meta-package pulls: sssd-ad, sssd-ipa, sssd-krb5, sssd-ldap, sssd-proxy
# This covers AD, FreeIPA, Kerberos, LDAP, and legacy proxy - any enterprise
# directory a user might encounter just works.
#
# Base Fedora Atomic already includes: sssd-common, sssd-client, sssd-kcm,
# sssd-krb5-common, krb5-libs, cyrus-sasl-gssapi, nfs-utils, gssproxy,
# samba-client, samba-client-libs, samba-common, cifs-utils, and all gvfs
# backends (gvfs-smb, gvfs-nfs, gvfs-fuse, gvfs-goa). We don't re-add those.
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

dnf5 -y remove glib2-devel

# -----------------------------------------------------------------------------
# Re-enable renamed services
#
# strip-bazzite.sh disabled the bazzite-* originals.
# rename-scripts.sh renamed them to defenestra-*.
# We re-enable them here under their new names.
# -----------------------------------------------------------------------------

systemctl enable nix.mount 2>/dev/null || true
systemctl enable nix-daemon.socket 2>/dev/null || true

# Docker: socket-activated, daemon starts on first use.
systemctl enable docker.socket 2>/dev/null || true

systemctl enable defenestra-flatpak-manager.service 2>/dev/null || true
systemctl enable defenestra-hardware-setup.service 2>/dev/null || true
systemctl enable defenestra-libvirtd-setup.service 2>/dev/null || true
systemctl --global enable defenestra-dynamic-fixes.service 2>/dev/null || true
systemctl --global enable defenestra-user-setup.service 2>/dev/null || true

# Handheld (only exists on deck images)
systemctl enable defenestra-tdpfix.service 2>/dev/null || true
systemctl enable defenestra-autologin.service 2>/dev/null || true

echo ":: defenestraOS packages installed."
