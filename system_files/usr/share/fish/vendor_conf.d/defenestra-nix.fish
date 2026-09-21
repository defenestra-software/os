# SPDX-License-Identifier: GPL-3.0-or-later

if test -d /nix/var/nix/profiles/default
    fish_add_path --global --move --path \
        "$HOME/.nix-profile/bin" /nix/var/nix/profiles/default/bin
    set --global --export NIXPKGS_ALLOW_UNFREE 1
end
