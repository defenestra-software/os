# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# Mirror Nix profile dirs into XDG_DATA_DIRS / PATH for login shells (TTY, SSH).
# systemd --user gets the same via /usr/lib/environment.d/90-defenestra-nix.conf.
# Fedora's /etc/profile.d/nix.sh handles NIX_PROFILES + man path; we extend it.

if [ -d /nix/var/nix/profiles/default ]; then
    case ":${PATH}:" in
        *":/nix/var/nix/profiles/default/bin:"*) ;;
        *) PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}" ;;
    esac
    export PATH

    case ":${XDG_DATA_DIRS:-}:" in
        *":/nix/var/nix/profiles/default/share:"*) ;;
        *) XDG_DATA_DIRS="${HOME}/.nix-profile/share:/nix/var/nix/profiles/default/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;;
    esac
    export XDG_DATA_DIRS

    # Allow unfree packages by default
    export NIXPKGS_ALLOW_UNFREE=1
fi

# Surface host Mesa/Vulkan/NVIDIA userspace to nix-built GPU apps. The dir
# is curated (GPU drivers + direct deps only), so prepending it to
# LD_LIBRARY_PATH cannot shadow libc/libssl/libstdc++/etc. in nix processes.
if [ -d /run/opengl-driver/lib ]; then
    case ":${LD_LIBRARY_PATH:-}:" in
        *":/run/opengl-driver/lib:"*) ;;
        *) LD_LIBRARY_PATH="/run/opengl-driver/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
    export LD_LIBRARY_PATH
fi
