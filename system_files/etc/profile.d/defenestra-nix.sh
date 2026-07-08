# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# Put Nix profile bin on PATH for login shells (TTY, SSH).
# systemd --user gets the same via /usr/lib/environment.d/90-defenestra-nix.conf.
# Fedora's /etc/profile.d/nix.sh handles NIX_PROFILES + man path; we extend it.

if [ -d /nix/var/nix/profiles/default ]; then
    # Guard on the user marker (~/.nix-profile/bin) too: environment.d emits it
    # first for the systemd user session, so a login shell in a graphical login
    # must be a no-op here to avoid duplicate entries.
    case ":${PATH}:" in
        *":${HOME}/.nix-profile/bin:"*) ;;
        *":/nix/var/nix/profiles/default/bin:"*) ;;
        *) PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}" ;;
    esac
    export PATH

    # Allow unfree packages by default
    export NIXPKGS_ALLOW_UNFREE=1
fi

# Surface host mesa to nix apps for login shells too. The dir
# is curated (GPU drivers + direct deps only), so prepending it cannot shadow
# libc/libssl/libstdc++/etc. in nix processes.
if [ -d /run/opengl-driver/lib ]; then
    case ":${LD_LIBRARY_PATH:-}:" in
        *":/run/opengl-driver/lib:"*) ;;
        *) LD_LIBRARY_PATH="/run/opengl-driver/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
    export LD_LIBRARY_PATH
fi
