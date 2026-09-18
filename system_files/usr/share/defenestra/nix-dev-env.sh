# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# PKG_CONFIG_PATH only: can shadow system .pc files; prefer `nix develop` for isolation.
for _d in \
    "${HOME}/.nix-profile/lib/pkgconfig" \
    "${HOME}/.nix-profile/share/pkgconfig" \
    /nix/var/nix/profiles/default/lib/pkgconfig \
    /nix/var/nix/profiles/default/share/pkgconfig
do
    case ":${PKG_CONFIG_PATH:-}:" in
        *":${_d}:"*) ;;
        *) PKG_CONFIG_PATH="${_d}${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" ;;
    esac
done
unset _d
export PKG_CONFIG_PATH
