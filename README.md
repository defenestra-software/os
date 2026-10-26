# defenestraOS

![Defenestra](./system_files/usr/share/icons/hicolor/256x256/defenestra-logo-icon.png)

defenestraOS is an immutable system based on Universal blue and Bazzite. Its goal is to be user friendly, secure by default (within reason), and stable. It provides compatibility and integrations where needed, so it fits into existing work environments and runs the software you depend on.

## Features

- Security enhancements
  - Signed images: every update is verified against the defenestraOS key before it is applied
  - Kernel and network hardening without breaking debugging and eBPF tools
  - Atomic updates with rollback to the previous image
  - Secure Boot support and SELinux enforcing enabled
  - USBGuard, U2F/YubiKey login, and fscrypt installed and ready to turn on
- Multiple supported package managers all unified behind a graphical store
  - Flatpak
  - Homebrew (with shared system user)
  - Nix (per-user and system-wide)
  - Snap (disabled by default)
  - AppImage
- A desktop that fits how you work
  - First-run onboarding allowing user to pick layout, browser, apps, and configure their phone
- Desktop layouts, switchable at any time from Arsenal
  - Modern (the default)
  - Vanilla GNOME
  - GNOME Classic
  - Windows-like, Windows 11-like, Windows List-like, Windows Classic
  - Mac-like
  - ChromeOS-like
  - Ubuntu-like
  - Mint-like
  - elementary OS-like
  - KDE Plasma-like
  - Budgie-like
  - Touch
  - Compact
  - Tiling
  - Scrolling (using PaperWM)
- Ready for work networks
  - Join FreeIPA and Active Directory domains
  - Network printers and scanners are found and automatically setup
- Hardware support
  - NVIDIA variants with the proprietary or open driver
  - GPU compute for AMD (ROCm) and Intel, including Intel NPUs
  - Bazzite's gaming stack and handheld support
- Containers
  - Docker
  - Podman
  - Toolbox
  - Incus system containers
- Virtual machines
  - Incus virtual machines
  - Hyperpane integration: log in to a virtual machine straight from the login screen
  - Early GPU binding at boot for Hyperpane GPU passthrough
- System management
  - Chassis device manager for hardware and drivers
  - Cockpit for remote administration

## Variants

Every variant is published to `ghcr.io/defenestra-software` and has its own installer ISO.

| Image | For |
| --- | --- |
| `defenestraos` | Desktops and laptops with AMD or Intel graphics |
| `defenestraos-nvidia` | NVIDIA graphics, proprietary driver |
| `defenestraos-nvidia-open` | NVIDIA graphics, open kernel modules |
| `defenestraos-deck` | Handhelds with AMD or Intel graphics |

Each image has three channels, used as the image tag:

- `stable` is what the ISOs install and what most machines should follow.
- `beta` is the next stable candidate.
- `canary` is rebuilt every day.

An image reaches `beta` and `stable` by promotion, so the image on `stable` is the same one that was tested on `canary`.

## System Requirements

| | Minimum | Recommended |
| --- | --- | --- |
| Processor | 64-bit Intel or AMD (x86_64) | 2 GHz quad-core or better |
| Memory | 4 GB | 8 GB or more |
| Storage | 64 GB | 120 GB or more on an SSD |
| Firmware | UEFI. CSM/Legacy boot is not supported. | |
| Graphics | AMD, Intel, or NVIDIA. See [Variants](#variants) for the NVIDIA images. | A card that supports Vulkan 1.3, for gaming |

Installation is slow on a 4 GB machine. The base system takes approximately 10 GB of disk including only core apps, not including apps installed during onboarding.

## Downloading

Choose the installer ISO that matches your hardware, write it to a USB drive, and boot from it.

| Hardware | ISO | Checksum |
| --- | --- | --- |
| AMD or Intel graphics | [defenestraos](https://os.defenestra.io/iso/latest/defenestraos-stable-live-amd64.iso) | [SHA-256](https://os.defenestra.io/iso/latest/defenestraos-stable-live-amd64.iso-CHECKSUM) |
| NVIDIA RTX, or GTX 16xx series and newer | [defenestraos-nvidia-open](https://os.defenestra.io/iso/latest/defenestraos-nvidia-open-stable-live-amd64.iso) | [SHA-256](https://os.defenestra.io/iso/latest/defenestraos-nvidia-open-stable-live-amd64.iso-CHECKSUM) |
| NVIDIA GTX 9xx to 10xx series | [defenestraos-nvidia](https://os.defenestra.io/iso/latest/defenestraos-nvidia-stable-live-amd64.iso) | [SHA-256](https://os.defenestra.io/iso/latest/defenestraos-nvidia-stable-live-amd64.iso-CHECKSUM) |
| Handhelds with AMD or Intel graphics | [defenestraos-deck](https://os.defenestra.io/iso/latest/defenestraos-deck-stable-live-amd64.iso) | [SHA-256](https://os.defenestra.io/iso/latest/defenestraos-deck-stable-live-amd64.iso-CHECKSUM) |

Each ISO is 6 to 8 GB. To check a download, save the checksum file next to the ISO and run:

```bash
sha256sum -c defenestraos-stable-live-amd64.iso-CHECKSUM
```

## Rebasing

A machine already running Fedora Atomic or a Universal Blue image can switch to defenestraOS without reinstalling. Your home directory, Brew packages, and Flatpaks are kept.

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/defenestra-software/defenestraos:stable
systemctl reboot
```

Replace `defenestraos` with another image from the [Variants](#variants) table, or `stable` with another channel, as needed. On the first boot, the system switches itself to the signed reference, so every later update is verified before it is applied. The first boot runs a one-time setup that migrates Homebrew to a BTFS subvolume, this can take several minutes.

## Verification

These images are signed with sigstore's [cosign](https://docs.sigstore.dev/cosign/key_management/overview/). You can verify the signature by downloading the [`cosign.pub`](./cosign.pub) key from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/defenestra-software/defenestraos:stable
```

An installed system does this on its own. The image ships the key and a container policy that rejects any defenestraOS update that is not signed with it.

## Secure Boot

> [!WARNING]
> **Steam Deck users: the Steam Deck does not come with Secure Boot enabled and does not ship with any keys enrolled by default. Do not enable this unless you absolutely know what you're doing.**

Secure Boot is supported with the Universal Blue key, which signs the kernel and drivers defenestraOS inherits from Bazzite. The public key is in the Universal Blue akmods repository [here](https://github.com/ublue-os/akmods/raw/main/certs/public_key.der).

The installer queues this key for enrollment. On the first boot after installing, the firmware asks whether to enroll it.

If you'd like to enroll the key before installing or rebasing, download it and run the following:

```bash
sudo mokutil --timeout -1
sudo mokutil --import public_key.der
```

On a machine already running defenestraOS, you may instead run `ujust enroll-secure-boot-key`.

If asked for a password, use `universalblue`.

## Building

Images are built with [podman](https://podman.io/) and [just](https://just.systems/). Run `just` with no arguments to list every recipe.

Build one variant, or all of them:

```bash
just build                       # defenestraos
just build defenestraos-nvidia   # any image from the Variants table
just build-desktop               # the three desktop variants
just build-all                   # everything
```

Images are tagged `localhost/<image>:latest`. Set `BASE_TAG` to build on a Bazzite tag other than `stable`.

Build the installer ISO from an image you have already built. The ISO lands in `output/`.

```bash
just build-live-iso
just run-vm-live-iso
```

Build and boot a disk image in a virtual machine:

```bash
just build-qcow2
just run-vm-qcow2
```

Before committing:

```bash
just check    # Justfile syntax
just lint     # shellcheck
just format   # shfmt
```
