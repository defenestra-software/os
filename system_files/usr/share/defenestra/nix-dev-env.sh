# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# defenestraOS: expose the Nix profile's pkg-config files so builds can find
# nix-installed libraries. Opt-in, toggled by `ujust enable-nix-dev` /
# `ujust disable-nix-dev` (symlinked into the shell's rc dir).
#
# Scoped to PKG_CONFIG_PATH on purpose. It can shadow system .pc files in
# non-nix builds, so for real per-project isolation prefer `nix develop`.
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
