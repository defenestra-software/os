#!/usr/bin/bash
# DefenestraOS live session login script
# Shows hardware info via conky and welcome dialog

# Require UEFI
if [[ ! -d /sys/firmware/efi ]]; then
    yad --undecorated --on-top --timeout=0 --button=Shutdown:0 \
        --text="DefenestraOS does not support CSM/Legacy Boot. Please boot into your UEFI/BIOS settings, disable CSM/Legacy Mode, and reboot." || true
    systemctl poweroff || shutdown -h now || true
fi

welcome_dialog() {
    _EXITLOCK=1
    _RETVAL=0
    local welcome_text="
Welcome to the DefenestraOS Live ISO\\!

The Live ISO is designed for installation and troubleshooting.
It does <b>not</b> have drivers and is <b>not capable of playing games.</b>

Please <b>do not use it in benchmarks</b> as it
does not represent the installed experience."
    while [[ $_EXITLOCK -eq 1 ]]; do
        yad \
            --no-escape \
            --on-top \
            --timeout-indicator=bottom \
            --text-align=center \
            --buttons-layout=center \
            --title="Welcome" \
            --text="$welcome_text" \
            --button="Install DefenestraOS":10 \
            --button="Launch Bootloader Restoring tool":20 \
            --button="Close dialog":0
        _RETVAL=$?
        case $_RETVAL in
        10)
            liveinst &
            disown $!
            _EXITLOCK=0
            ;;
        20)
            /usr/bin/bootloader_restore &
            disown $!
            _EXITLOCK=0
            ;;
        0) _EXITLOCK=0 ;;
        esac
    done
}

# Check for existing Linux bootloaders on EFI partitions
efi="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
declare -A mount
while read -r device path; do
    mount["$device"]="-o bind,ro $path"
done < <(lsblk -o PATH,MOUNTPOINTS -nQ 'PARTTYPE=="'$efi'" && MOUNTPOINTS' 2>/dev/null || true)

for device in $(lsblk -o PATH -nQ 'PARTTYPE=="'$efi'" && !MOUNTPOINTS' 2>/dev/null || true); do
    mount["$device"]="-o ro -t vfat $device"
done

export mnt=$(mktemp -d)
trap "rmdir '$mnt'" EXIT

for device in "${!mount[@]}"; do
    export device
    msg=$(sudo -E unshare -m sh -c '
        mount '"${mount[$device]} '$mnt'"' 2>/dev/null || exit 0
        shopt -s nullglob nocaseglob
        for dir in "$mnt"/EFI/*; do
            [ -d "$dir" ] || continue
            base=$(basename "$dir" | tr "[:upper:]" "[:lower:]")
            [[ "$base" == "fedora" || "$base" == "boot" ]] && continue
            grub=("$dir"/grub*.efi)
            (( ! ${#grub[@]} )) && continue
            echo "An existing GRUB bootloader was found on $device at ${dir#$mnt}\nDefenestraOS does not support dual boot with other Linux installations.\nInstalls to this disk that attempt to reuse this EFI partition will fail.\nEither DefenestraOS must be installed to a different disk, or this partition/bootloader must be removed.\n"
        done
    ' || true)
    [ "$msg" ] || continue
    yad --image=dialog-warning --button=OK --buttons-layout=center --title="Existing Linux bootloader detected" --text="$msg"
done

welcome_dialog
