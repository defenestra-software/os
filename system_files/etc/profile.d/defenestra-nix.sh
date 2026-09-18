# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# systemd --user gets the same via environment.d/90-defenestra-nix.conf.
# Fedora's /etc/profile.d/nix.sh handles NIX_PROFILES + man path; this extends it.

if [ -d /nix/var/nix/profiles/default ]; then
    # environment.d already prepended ~/.nix-profile/bin for graphical login.
    case ":${PATH}:" in
        *":${HOME}/.nix-profile/bin:"*) ;;
        *":/nix/var/nix/profiles/default/bin:"*) ;;
        *) PATH="${HOME}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}" ;;
    esac
    export PATH

    export NIXPKGS_ALLOW_UNFREE=1
fi

if [ -d /run/opengl-driver/lib ]; then
    case ":${LD_LIBRARY_PATH:-}:" in
        *":/run/opengl-driver/lib:"*) ;;
        *) LD_LIBRARY_PATH="/run/opengl-driver/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
    export LD_LIBRARY_PATH
fi
