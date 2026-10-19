#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -ouex pipefail

echo ":: Installing defenestraOS packages..."

dnf5 -y copr enable defenestra/defenestra
dnf5 -y install --refresh defenestra-chassis nsncd \
    gnome-shell-extension-hanabi \
    looking-glass-client \
    snapd
dnf5 -y copr disable defenestra/defenestra

install -Dm644 /ctx/system_files/etc/pki/rpm-gpg/RPM-GPG-KEY-defenestra \
    /etc/pki/rpm-gpg/RPM-GPG-KEY-defenestra
install -Dm644 /ctx/system_files/etc/yum.repos.d/defenestra.repo \
    /etc/yum.repos.d/defenestra.repo

# Verify registry images with Defenestra's CI signing key.
install -Dm644 /ctx/cosign.pub /etc/pki/containers/defenestra.pub

# Accept images signed with the offline recovery key.
install -Dm644 /ctx/cosign-backup.pub /etc/pki/containers/defenestra-backup.pub
jq '.transports.docker["ghcr.io/defenestra-software"] = [{
        "type": "sigstoreSigned",
        "keyPaths": [
            "/etc/pki/containers/defenestra.pub",
            "/etc/pki/containers/defenestra-backup.pub"
        ],
        "signedIdentity": {"type": "matchRepository"}
    }]' /etc/containers/policy.json >/tmp/policy.json
mv /tmp/policy.json /etc/containers/policy.json
dnf5 -y install --enable-repo=defenestra defenestra-store defenestra-store-services \
    hyperpane-display defenestra-arsenal

dnf5 -y install \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-window-list \
    gnome-shell-extension-light-style \
    gnome-shell-extension-drive-menu

dnf5 -y install gnome-initial-setup nautilus-python

# xdg-user-dirs 0.19 lacks a PROJECTS entry.
grep -q '^PROJECTS=' /etc/xdg/user-dirs.defaults || echo 'PROJECTS=Projects' >>/etc/xdg/user-dirs.defaults

dnf5 -y install zsh

# gnome-initial-setup hides Linuxbrew because its UID is below 1000.
# Defenestra manages Linuxbrew through its own units.
systemd-sysusers /ctx/system_files/usr/lib/sysusers.d/defenestra-linuxbrew.conf
systemctl mask brew-setup.service brew-update.service brew-update.timer \
    brew-upgrade.service brew-upgrade.timer 2>/dev/null || true

dnf5 -y install toolbox

# mesa-libOpenCL conflicts with ROCm's OpenCL ICD.
# Skip weak test and debug dependencies while keeping the requested compute libraries.
dnf5 -y remove mesa-libOpenCL
dnf5 -y --setopt=install_weak_deps=False install \
    rocm-opencl \
    rocm-clinfo \
    rocm-smi \
    rocminfo

dnf5 -y --setopt=install_weak_deps=False install \
    intel-compute-runtime \
    oneapi-level-zero \
    intel-level-zero-gpu-raytracing \
    intel-npu-driver \
    igt-gpu-tools

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

dnf5 -y install simple-scan

# Enable these per user or organization policy.
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
echo iptable_nat >/etc/modules-load.d/defenestra-docker.conf

# Store in /var/nix; nix.mount binds it onto /nix at boot.
dnf5 -y install nix nix-daemon busybox
mkdir -p /usr/share/factory/var/nix
cp -a /nix/. /usr/share/factory/var/nix/
rm -rf /nix/*

# Fedora has no SELinux policy for /nix. nix.pp lets init_t traverse store links
# during socket activation. Load it from /ctx because overlays run later.
semodule -i /ctx/system_files/usr/share/selinux/packages/defenestra/nix.pp
# Factory copy only; first-boot defenestra-nix-store-relabel relabels the live store.
restorecon -RF /usr/share/factory/var/nix

# Off by default. Classic snaps hardcode /snap.
dnf5 -y install snapd
if ! rpm -q --qf '%{RELEASE}\n' snapd | grep -q defenestra; then
    echo "!! snapd $(rpm -q snapd) is not the patched defenestra build" >&2
    exit 1
fi
systemctl disable snapd.socket 2>/dev/null || true
ln -s var/lib/snapd/snap /snap
semanage fcontext -N -a -t snappy_var_lib_t '/snap'

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

# Bazzite strips file caps from SSSD helpers (LDAP/Kerberos). See ublue-os/bazzite#1818.
if [ -f /usr/libexec/sssd/krb5_child ]; then
    setcap cap_chown,cap_dac_override,cap_setgid,cap_setuid=ep /usr/libexec/sssd/krb5_child
    setcap cap_chown,cap_dac_override,cap_setgid,cap_setuid=ep /usr/libexec/sssd/ldap_child
    setcap cap_dac_read_search=p /usr/libexec/sssd/sssd_pam
    echo ":: SSSD binary capabilities restored."
fi

flatpak remote-add --if-not-exists --from defenestra \
    https://my.defenestra.io/downloads/defenestra.flatpakrepo

if [ -d /ctx/system_files ] && [ "$(ls -A /ctx/system_files 2>/dev/null)" ]; then
    rsync -av --exclude='usr/share/gnome-shell/extensions' --exclude='nvidia' /ctx/system_files/ /
    echo ":: System files overlaid."

    if [[ "${IMAGE_VARIANT:-}" == *nvidia* ]] && [ -d /ctx/system_files/nvidia ]; then
        rsync -av /ctx/system_files/nvidia/ /
        echo ":: Nvidia system files overlaid."
    fi
else
    echo ":: No system_files to overlay (skeleton build)."
fi

# sysusers does not change the ID of an existing group.
systemd-sysusers /usr/lib/sysusers.d/defenestra-plugdev.conf
plugdev_gid="$(getent group plugdev | cut -d: -f3)"
if [ "$plugdev_gid" != 46 ]; then
    if awk -F: '$3 == 46' /usr/lib/group /etc/group | grep -q .; then
        echo ":: gid 46 is already taken, cannot renumber plugdev" >&2
        exit 1
    fi
    sed -i "s/^plugdev:x:${plugdev_gid}:/plugdev:x:46:/" /usr/lib/group /etc/group
    find / -xdev -gid "$plugdev_gid" -exec chgrp -h 46 {} +
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

if [ -d "${BUNDLED_EXT_SRC}/store-integration@defenestra.io" ]; then
    cp -r "${BUNDLED_EXT_SRC}/store-integration@defenestra.io" "${BUNDLED_EXT_DST}/"
fi

if [ -d "${BUNDLED_EXT_SRC}/clipboard-indicator@tudmotu.com" ]; then
    cp -r "${BUNDLED_EXT_SRC}/clipboard-indicator@tudmotu.com" "${BUNDLED_EXT_DST}/"
    if [ -d "${BUNDLED_EXT_DST}/clipboard-indicator@tudmotu.com/schemas" ]; then
        glib-compile-schemas "${BUNDLED_EXT_DST}/clipboard-indicator@tudmotu.com/schemas"
    fi
fi

# ArcMenu ships src/ nested; flatten to the extension root.
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

command -v unzip >/dev/null 2>&1 || dnf5 -y install unzip
install_ego_extension() {
    local uuid="$1" version="$2" sha256="$3"
    local url="https://extensions.gnome.org/extension-data/${uuid//@/}.v${version}.shell-extension.zip"
    local dst="${BUNDLED_EXT_DST}/${uuid}"
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL -o "${tmp}/ext.zip" "${url}"
    echo "${sha256}  ${tmp}/ext.zip" | sha256sum -c -
    mkdir -p "${dst}"
    unzip -q -o "${tmp}/ext.zip" -d "${dst}"
    if [ -d "${dst}/schemas" ]; then
        glib-compile-schemas "${dst}/schemas"
    fi
    rm -rf "${tmp}"
}

install_ego_extension tilingshell@ferrarodomenico.com 76 \
    0a9f2b26de65294f53350d74089a3dae9376642784a722e98fc8d78fcc470a35
install_ego_extension gnome-mosaic@jardon.github.com 19 \
    7a4f657f2029504b5eec500690225e011aaab27ef10e7630b9a8b1ce155e6ebd
install_ego_extension paperwm@paperwm.github.com 148 \
    2cef72ed7e31df4962584b52dabda9246c0ae81973b05f8d1202d9dbe9a3f794

MOREWAITA_COMMIT="8ee561313b9737fa960d75ce2ac91846b4576df7"
MOREWAITA_SHA256="599d8cecaef0fac3c46df5d448748854fbc7cbe851f5a911c7018befdb060c42"
MOREWAITA_URL="https://github.com/somepaulo/MoreWaita/archive/${MOREWAITA_COMMIT}.tar.gz"
MOREWAITA_DST="/usr/share/icons/MoreWaita"
MOREWAITA_TMP="$(mktemp -d)"
curl -fsSL -o "${MOREWAITA_TMP}/mw.tar.gz" "${MOREWAITA_URL}"
echo "${MOREWAITA_SHA256}  ${MOREWAITA_TMP}/mw.tar.gz" | sha256sum -c -
tar -xzf "${MOREWAITA_TMP}/mw.tar.gz" -C "${MOREWAITA_TMP}" --strip-components=1
mkdir -p "${MOREWAITA_DST}"
cp -a "${MOREWAITA_TMP}"/{index.theme,AUTHORS,LICENSE,scalable,symbolic} "${MOREWAITA_DST}/"
find "${MOREWAITA_DST}" -name meson.build -delete
rm -rf "${MOREWAITA_TMP}"
gtk-update-icon-cache -q -f "${MOREWAITA_DST}"
/ctx/build_files/gen-icon-theme.sh /usr/share/icons/Adwaita "${MOREWAITA_DST}" /usr/share/icons/Defenestra

# NVIDIA's ICD uses a bare soname. Loading two libGLX_nvidia copies segfaults glcore.
if [ -e /usr/share/vulkan/icd.d/nvidia_icd.x86_64.json ]; then
    mkdir -p /etc/vulkan/icd.d
    sed -E 's|("library_path"[[:space:]]*:[[:space:]]*")[^"]*libGLX_nvidia\.so\.0"|\1libGLX_nvidia.so.0"|' \
        /usr/share/vulkan/icd.d/nvidia_icd.x86_64.json >/etc/vulkan/icd.d/nvidia_icd.json
    rm -f /usr/share/vulkan/icd.d/nvidia_icd.*.json
fi

# Use the current stable NixOS channel. Mesa needs its newer glibc.
# Update this with each NixOS release.
mkdir -p /usr/share/defenestra
curl -fsSL https://channels.nixos.org/nixos-26.05/git-revision \
    >/usr/share/defenestra/opengl-nixpkgs-rev

systemctl enable defenestra-nix-reseed.service 2>/dev/null || true
systemctl enable nix.mount 2>/dev/null || true
systemctl enable defenestra-nix-store-relabel.service 2>/dev/null || true
systemctl enable nix-daemon.socket 2>/dev/null || true
# Nix binaries need host SSSD and FreeIPA identities.
systemctl enable nsncd.service 2>/dev/null || true
systemctl enable defenestra-opengl-provision.service 2>/dev/null || true
systemctl enable defenestra-opengl-provision.path 2>/dev/null || true
systemctl enable defenestra-opengl-compose.service 2>/dev/null || true

systemctl enable docker.socket 2>/dev/null || true

systemctl --global enable snapd.session-agent.socket 2>/dev/null || true

systemctl enable defenestra-brew-setup.service 2>/dev/null || true
systemctl enable defenestra-verify-image.service 2>/dev/null || true
systemctl enable defenestra-brew-zsh-completions.service 2>/dev/null || true
systemctl enable defenestra-brew-zsh-completions.path 2>/dev/null || true
systemctl enable store-system.service 2>/dev/null || true
systemctl --global enable store-user.service 2>/dev/null || true

# Store owns OS and app updates.
for unit in \
    uupd.timer \
    bootc-fetch-apply-updates.timer \
    rpm-ostreed-automatic.timer; do
    systemctl mask "${unit}" 2>/dev/null || true
done

systemctl enable defenestra-flatpak-manager.service 2>/dev/null || true
systemctl enable defenestra-hardware-setup.service 2>/dev/null || true
systemctl --global enable defenestra-dynamic-fixes.service 2>/dev/null || true
systemctl --global enable defenestra-user-setup.service 2>/dev/null || true
systemctl --global enable defenestra-folder-icons.service 2>/dev/null || true

# Restrict discovery to DNS-SD. CUPS' UDP/631 listener is affected by CVE-2024-47176.
grep -qx 'BrowseRemoteProtocols none' /etc/cups/cups-browsed.conf
sed -i 's/^BrowseRemoteProtocols none$/BrowseRemoteProtocols dnssd/' /etc/cups/cups-browsed.conf
cat >>/etc/cups/cups-browsed.conf <<'EOF'

# Keep PPD-defined color printers from defaulting to grayscale.
CreateIPPPrinterQueues Driverless
DefaultOptions ColorModel=RGB
EOF
systemctl enable cups-browsed.service 2>/dev/null || true
systemctl enable defenestra-cups-browsed-resume.service 2>/dev/null || true

# These services no-op outside Steam Deck systems.
systemctl enable defenestra-tdpfix.service 2>/dev/null || true
systemctl enable defenestra-autologin.service 2>/dev/null || true

echo ":: defenestraOS packages installed."
