#!/usr/bin/env bash
# DefenestraOS post-rootfs hook for live ISO
# Installs Anaconda, configures live session, sets up installer kickstart

set -exo pipefail

source /etc/os-release

# Remove all versionlocks to avoid dependency issues
dnf -qy versionlock clear

# Install Anaconda and dependencies (may pull fedora-logos, overwriting our branding)
dnf install -qy --enable-repo=fedora-cisco-openh264 --allowerasing firefox anaconda-live libblockdev-{btrfs,lvm,dm}

# Reinstall our branding RPM — Anaconda pulls in fedora-logos which overwrites ours
dnf -qy copr enable defenestra/defenestra
dnf -qy install --allowerasing --refresh defenestra-branding
dnf -qy copr disable defenestra/defenestra

mkdir -p /var/lib/rpm-state

# Utilities for dialogs
dnf install -qy --setopt=install_weak_deps=0 qrencode yad

# Variables
imageref="$(podman images --format '{{ index .Names 0 }}\n' 'defenestra*' | head -1)"
imageref="${imageref##*://}"
imageref="${imageref%%:*}"
imagetag="$(podman images --format '{{ .Tag }}\n' "$imageref" | head -1)"
sbkey='https://github.com/ublue-os/akmods/raw/main/certs/public_key.der'
SECUREBOOT_KEY="/usr/share/ublue-os/sb_pubkey.der"

: ${VARIANT_ID:?}

echo "DefenestraOS release $VERSION_ID" >/etc/system-release

# Anaconda branding — use our pixmaps if available
if [ -d /src/branding ]; then
    mkdir -p /usr/share/anaconda/pixmaps/silverblue
    cp -r /src/branding/* /usr/share/anaconda/pixmaps/
fi

# Installer icon — use defenestra logo
for f in \
    /usr/share/icons/hicolor/48x48/apps/org.fedoraproject.AnacondaInstaller.svg \
    /usr/share/icons/hicolor/scalable/apps/org.fedoraproject.AnacondaInstaller.svg; do
    if [ -f /usr/share/icons/hicolor/scalable/apps/defenestra-logo-icon.svg ]; then
        cp /usr/share/icons/hicolor/scalable/apps/defenestra-logo-icon.svg "$f"
    fi
done

# Secureboot Key Fetch
mkdir -p /usr/share/ublue-os
curl -Lo /usr/share/ublue-os/sb_pubkey.der "$sbkey"

# Default Kickstart
cat <<EOF >>/usr/share/anaconda/interactive-defaults.ks

# Create log directory
%pre
mkdir -p /tmp/anacoda_custom_logs
%end

# Check if there is a bitlocker partition and warn the user
%pre --erroronfail --log=/tmp/anacoda_custom_logs/detect_bitlocker.log
IS_BITLOCKER=\$(lsblk -o FSTYPE --json | jq '.blockdevices | map(select(.fstype == "BitLocker")) | . != []')
{ WARNING_MSG="\$(</dev/stdin)"; } << 'WARNINGEOF'
<span size="x-large">Windows Bitlocker partition detected</span>

It might interrupt the installation process.
In such case, please, do <b>one</b> of the following:
    a) Disconnect its storage drive.
    b) Disable Bitlocker in Windows.
    c) Delete it in GNOME Disks.

Do you wish to continue?
WARNINGEOF

if [[ \$IS_BITLOCKER =~ true ]]; then
    _EXITLOCK=1
    while [[ \$_EXITLOCK -ne 0 ]]; do
        run0 --user=liveuser yad \
            --on-top \
            --timeout=10 \
            --text="\$WARNING_MSG" \
            --button="Yes, I'm aware, continue":0 --button="Cancel installation":10
        _RETCODE=\$?
        case \$_RETCODE in
            0) _EXITLOCK=0; ;;
            10) _EXITLOCK=0; pkill liveinst; pkill firefox; exit 0 ;;
        esac
    done
fi
%end

# Remove the efi dir
%pre-install --erroronfail
rm -rf /mnt/sysroot/boot/efi/EFI/fedora
%end

# Relabel the boot partition
%pre-install --erroronfail --log=/tmp/anacoda_custom_logs/repartitioning.log
set -x
xboot_dev=\$(findmnt -o SOURCE --nofsroot --noheadings -f --target /mnt/sysroot/boot)
if [[ -z \$xboot_dev ]]; then
  echo "ERROR: xboot_dev not found"
  exit 1
fi
e2label "\$xboot_dev" "defenestra_xboot"
%end

# Error dialog
%onerror
run0 --user=liveuser yad \
    --timeout=0 \
    --text-info \
    --no-buttons \
    --width=600 \
    --height=400 \
    --text="An error occurred during installation. Please report this issue." \
    < /tmp/anaconda.log
%end

ostreecontainer --url=$imageref:$imagetag --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%include /usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks
%include /usr/share/anaconda/post-scripts/install-flatpaks.ks
%include /usr/share/anaconda/post-scripts/flatpak-restore-selinux-labels.ks
%include /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks

EOF

# Signed Images — switch to registry transport after install
cat <<EOF >>/usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%post --erroronfail --log=/tmp/anacoda_custom_logs/bootc-switch.log
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry $imageref:$imagetag
%end
EOF

# Enroll Secureboot Key
cat <<EOF >>/usr/share/anaconda/post-scripts/secureboot-enroll-key.ks
%post --erroronfail --nochroot --log=/tmp/anacoda_custom_logs/secureboot-enroll-key.log
set -oue pipefail

readonly ENROLLMENT_PASSWORD="universalblue"
readonly SECUREBOOT_KEY="$SECUREBOOT_KEY"

if [[ ! -d "/sys/firmware/efi" ]]; then
    echo "EFI mode not detected. Skipping key enrollment."
    exit 0
fi

if [[ ! -f "\$SECUREBOOT_KEY" ]]; then
    echo "Secure boot key not provided: \$SECUREBOOT_KEY"
    exit 0
fi

SYS_ID="\$(cat /sys/devices/virtual/dmi/id/product_name)"
if [[ ":Jupiter:Galileo:" =~ ":\$SYS_ID:" ]]; then
    echo "Steam Deck hardware detected. Skipping key enrollment."
    exit 0
fi

mokutil --timeout -1 || :
echo -e "\$ENROLLMENT_PASSWORD\n\$ENROLLMENT_PASSWORD" | mokutil --import "\$SECUREBOOT_KEY" || :
%end
EOF

### Live session tweaks ###

# Disable services not needed in live session
(
    set +e
    for s in \
        rpm-ostree-countme.service \
        tailscaled.service \
        defenestra-hardware-setup.service \
        bootloader-update.service \
        brew-upgrade.timer \
        brew-update.timer \
        brew-setup.service \
        rpm-ostreed-automatic.timer \
        uupd.timer \
        ublue-guest-user.service \
        ublue-os-media-automount.service \
        ublue-system-setup.service \
        check-sb-key.service; do
        systemctl disable $s
    done

    for s in \
        defenestra-flatpak-manager.service \
        podman-auto-update.timer \
        defenestra-user-setup.service; do
        systemctl --global disable $s
    done
)

# Use GSK_RENDERER=gl for nvidia (workaround for GTK apps not opening)
if [[ $imageref == *-nvidia* ]]; then
    mkdir -p /etc/environment.d /etc/skel/.config/environment.d
    echo "GSK_RENDERER=gl" >>/etc/environment.d/99-nvidia-fix.conf
    echo "GSK_RENDERER=gl" >>/etc/skel/.config/environment.d/99-nvidia-fix.conf
fi

# Re-enable nouveau for live session (nvidia images)
if [[ $imageref == *-nvidia* ]]; then
    for pkg in nvidia-gpu-firmware mesa-vulkan-drivers; do
        dnf -yq reinstall --allowerasing $pkg ||
            dnf -yq install --allowerasing $pkg
    done
    (
        shopt -u nullglob
        ls /usr/share/vulkan/icd.d/nouveau_icd.*.json >/dev/null
    ) || {
        echo >&2 "::error::No nouveau vulkan icds found"
        exit 1
    }
fi

# Don't start Steam at login in live session
rm -vf /etc/skel/.config/autostart/steam*.desktop

# Remove packages not needed in live session
dnf -yq remove steam lutris bazaar || :

# Don't start fedora-welcome
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/anaconda/gnome/org.fedoraproject.welcome-screen.desktop || :

# Copy live session system files
echo "Copying shared system files..."
cp -af /src/system_files/shared/. /

echo "Copying GNOME-specific system files..."
cp -af /src/system_files/gnome/. / 2>/dev/null || true

# Compile schemas for live session overrides
glib-compile-schemas /usr/share/glib-2.0/schemas

# Install gparted for disk management
dnf -yq install gparted

dnf clean all
