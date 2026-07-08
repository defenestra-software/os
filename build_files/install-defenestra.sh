#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -ouex pipefail

echo ":: Installing defenestraOS packages..."

dnf5 -y copr enable defenestra/defenestra
dnf5 -y install --refresh defenestra-arsenal defenestra-chassis nsncd
dnf5 -y copr disable defenestra/defenestra

# Defenestra hosted repository
install -Dm644 /ctx/system_files/etc/pki/rpm-gpg/RPM-GPG-KEY-defenestra \
    /etc/pki/rpm-gpg/RPM-GPG-KEY-defenestra
install -Dm644 /ctx/system_files/etc/yum.repos.d/defenestra.repo \
    /etc/yum.repos.d/defenestra.repo
dnf5 -y install --enable-repo=defenestra defenestra-store defenestra-store-services

dnf5 -y install \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-light-style \
    gnome-shell-extension-drive-menu

dnf5 -y install gnome-initial-setup

dnf5 -y install zsh

# Brew is owned by the linuxbrew system user (UID < 1000 hides it from
# gnome-initial-setup). /usr/bin/brew wrapper routes through `sudo -u linuxbrew`
# so the prefix has one stable owner; wheel-only via sudoers.d/defenestra-brew.
# Mask upstream brew-* units; defenestra-brew-* own the lifecycle as linuxbrew.
systemd-sysusers /ctx/system_files/usr/lib/sysusers.d/defenestra-linuxbrew.conf
systemctl mask brew-setup.service brew-update.service brew-update.timer \
    brew-upgrade.service brew-upgrade.timer 2>/dev/null || true

dnf5 -y install toolbox

# Bazzite's mesa-libOpenCL (Rusticl) conflicts with ROCm's OpenCL ICD.
# install_weak_deps=False keeps only compute libs, skips test/debug recommends.
dnf5 -y remove mesa-libOpenCL
dnf5 -y --setopt=install_weak_deps=False install \
    rocm-hip \
    rocm-opencl \
    rocm-clinfo \
    rocm-smi

dnf5 -y install \
    bpftrace \
    bcc \
    flatpak-builder \
    waypipe \
    git-subtree \
    iotop \
    trace-cmd

dnf5 -y install \
    incus \
    incus-agent

dnf5 -y install \
    libappindicator-gtk3 \
    libayatana-appindicator-gtk3

dnf5 -y install \
    cockpit \
    cockpit-ostree

# Security opt-ins ship installed but disabled, enabled per user/org policy.
dnf5 -y install \
    usbguard \
    usbguard-notifier \
    pam-u2f \
    pamu2fcfg \
    yubikey-manager \
    fscrypt

dnf5 -y install \
    adwaita-fonts-all \
    jetbrains-mono-fonts-all \
    opendyslexic-fonts \
    google-roboto-fonts \
    google-roboto-condensed-fonts \
    google-roboto-mono-fonts \
    google-roboto-slab-fonts

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

# iptable_nat needed for docker-in-docker. See ublue-os/bluefin#2365.
mkdir -p /etc/modules-load.d
echo iptable_nat > /etc/modules-load.d/defenestra-docker.conf

# F44 nix-daemon ships multi-user systemd units. /var/nix holds the store;
# bound onto /nix via nix.mount at boot.
dnf5 -y install nix nix-daemon busybox
mkdir -p /usr/share/factory/var/nix
cp -a /nix/. /usr/share/factory/var/nix/
rm -rf /nix/*

# Fedora ships no SELinux policy for /nix. Determinate's nix.pp adds fcontext
# rules for store/socket/profiles plus `allow init_t default_t:lnk_file read`
# (init_t traverses symlinks during daemon socket activation; fcontext alone
# misses this). Source .te/.fc shipped beside .pp for audit. Load from /ctx
# since system_files overlay runs later.
semodule -i /ctx/system_files/usr/share/selinux/packages/defenestra/nix.pp
# Authoritative relabel happens on first boot via defenestra-nix-store-relabel
# once /var/nix is bind-mounted at /nix. This pass clears RPM-inherited
# contexts on the factory copy.
restorecon -RF /usr/share/factory/var/nix

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

# Bazzite's build strips file caps from SSSD helpers, breaking LDAP/Kerberos
# on atomic desktops. Kinoite with the same SSSD works fine, confirming this
# is a build artifact. See ublue-os/bazzite#1818.
if [ -f /usr/libexec/sssd/krb5_child ]; then
    setcap cap_chown,cap_dac_override,cap_setgid,cap_setuid=ep /usr/libexec/sssd/krb5_child
    setcap cap_chown,cap_dac_override,cap_setgid,cap_setuid=ep /usr/libexec/sssd/ldap_child
    setcap cap_dac_read_search=p /usr/libexec/sssd/sssd_pam
    echo ":: SSSD binary capabilities restored."
fi

flatpak remote-add --if-not-exists --from defenestra \
    https://my.defenestra.io/downloads/defenestra.flatpakrepo 2>/dev/null || true

if [ -d /ctx/system_files ] && [ "$(ls -A /ctx/system_files 2>/dev/null)" ]; then
    # Extensions handled below; nvidia overlay is conditional.
    rsync -av --exclude='usr/share/gnome-shell/extensions' --exclude='nvidia' /ctx/system_files/ /
    echo ":: System files overlaid."

    if [[ "${IMAGE_VARIANT:-}" == *nvidia* ]] && [ -d /ctx/system_files/nvidia ]; then
        rsync -av /ctx/system_files/nvidia/ /
        echo ":: Nvidia system files overlaid."
    fi
else
    echo ":: No system_files to overlay (skeleton build)."
fi

BUNDLED_EXT_SRC="/ctx/system_files/usr/share/gnome-shell/extensions"
BUNDLED_EXT_DST="/usr/share/gnome-shell/extensions"

dnf5 -y install glib2-devel

if [ -d "${BUNDLED_EXT_SRC}/no-startup-overview@defenestra.io" ]; then
    cp -r "${BUNDLED_EXT_SRC}/no-startup-overview@defenestra.io" "${BUNDLED_EXT_DST}/"
fi

if [ -d "${BUNDLED_EXT_SRC}/show-logout@defenestra.io" ]; then
    cp -r "${BUNDLED_EXT_SRC}/show-logout@defenestra.io" "${BUNDLED_EXT_DST}/"
fi

if [ -d "${BUNDLED_EXT_SRC}/clipboard-indicator@tudmotu.com" ]; then
    cp -r "${BUNDLED_EXT_SRC}/clipboard-indicator@tudmotu.com" "${BUNDLED_EXT_DST}/"
    if [ -d "${BUNDLED_EXT_DST}/clipboard-indicator@tudmotu.com/schemas" ]; then
        glib-compile-schemas "${BUNDLED_EXT_DST}/clipboard-indicator@tudmotu.com/schemas"
    fi
fi

# ArcMenu ships src/ + data/ + schemas/ in subdirs; flatten src/ to root and
# compile the gresource bundle.
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

# tiling-assistant ships nested in a same-named subdir.
if [ -d "${BUNDLED_EXT_SRC}/tiling-assistant@leleat-on-github/tiling-assistant@leleat-on-github" ]; then
    TA_SRC="${BUNDLED_EXT_SRC}/tiling-assistant@leleat-on-github/tiling-assistant@leleat-on-github"
    TA_DST="${BUNDLED_EXT_DST}/tiling-assistant@leleat-on-github"
    mkdir -p "${TA_DST}"
    cp -r "${TA_SRC}"/. "${TA_DST}/"
    glib-compile-schemas "${TA_DST}/schemas"
fi

# alphabetical-app-grid ships nested under extension/.
if [ -d "${BUNDLED_EXT_SRC}/AlphabeticalAppGrid@stuarthayhurst/extension" ]; then
    AAG_SRC="${BUNDLED_EXT_SRC}/AlphabeticalAppGrid@stuarthayhurst/extension"
    AAG_DST="${BUNDLED_EXT_DST}/AlphabeticalAppGrid@stuarthayhurst"
    mkdir -p "${AAG_DST}"
    cp -r "${AAG_SRC}"/. "${AAG_DST}/"
    glib-compile-schemas "${AAG_DST}/schemas"
fi

dnf5 -y remove glib2-devel

# Tiling Shell ships as prebuilt zip (TS/esbuild output with compiled schemas
# + gresource + .mo). Pulling source would drag nodejs/npm into the build.
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

# Build the curated /run/opengl-driver/{lib,lib32} backing directory
/ctx/build_files/curate-gl-libs.sh

# Pin the nixpkgs rev that defenestra-opengl-provision fetches Mesa from, so every
# machine off this image gets the identical, image-tested Mesa instead of whatever
# unstable happens to be on its first-boot day.
mkdir -p /usr/share/defenestra
curl -fsSL https://channels.nixos.org/nixpkgs-unstable/git-revision \
    > /usr/share/defenestra/opengl-nixpkgs-rev

systemctl enable defenestra-nix-reseed.service 2>/dev/null || true
systemctl enable nix.mount 2>/dev/null || true
systemctl enable defenestra-nix-store-relabel.service 2>/dev/null || true
systemctl enable nix-daemon.socket 2>/dev/null || true
# NSS bridge: lets Nix-built binaries resolve host sssd/FreeIPA identities.
systemctl enable nsncd.service 2>/dev/null || true
# xdg-sync mirrors Nix profile entries into XDG dirs so GNOME Shell shows new
# apps without relog. User unit lit via systemd/user-preset/90-defenestra.preset.
systemctl enable defenestra-nix-xdg-sync.path 2>/dev/null || true
systemctl --global enable defenestra-nix-xdg-sync.path 2>/dev/null || true
# Hybrid GL: first-boot fetch of a nix-built Mesa (glibc-consistent) and
# per-boot compose for /run/opengl-driver so nix GL/Vulkan apps stop
# breaking when Fedora's glibc outpaces the nix channel's. NVIDIA stays host.
systemctl enable defenestra-opengl-provision.service 2>/dev/null || true
systemctl enable defenestra-opengl-compose.service 2>/dev/null || true

systemctl enable docker.socket 2>/dev/null || true

systemctl enable defenestra-brew-setup.service 2>/dev/null || true
systemctl enable defenestra-brew-update.timer 2>/dev/null || true

systemctl enable defenestra-flatpak-manager.service 2>/dev/null || true
systemctl enable defenestra-hardware-setup.service 2>/dev/null || true
systemctl enable defenestra-libvirtd-setup.service 2>/dev/null || true
systemctl --global enable defenestra-dynamic-fixes.service 2>/dev/null || true
systemctl --global enable defenestra-user-setup.service 2>/dev/null || true

# Deck-only units; harmless no-op on desktop variants.
systemctl enable defenestra-tdpfix.service 2>/dev/null || true
systemctl enable defenestra-autologin.service 2>/dev/null || true

echo ":: defenestraOS packages installed."
