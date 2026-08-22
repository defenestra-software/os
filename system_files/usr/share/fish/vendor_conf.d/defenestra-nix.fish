# SPDX-License-Identifier: GPL-3.0-or-later

if test -d /nix/var/nix/profiles/default
    fish_add_path --global --move --path \
        "$HOME/.nix-profile/bin" /nix/var/nix/profiles/default/bin
    set --global --export NIXPKGS_ALLOW_UNFREE 1
end

# Nix binaries link against nix's Mesa; /run/opengl-driver from defenestra-opengl-compose.
if test -d /run/opengl-driver/lib
    if not contains /run/opengl-driver/lib $LD_LIBRARY_PATH
        set --global --export LD_LIBRARY_PATH /run/opengl-driver/lib $LD_LIBRARY_PATH
    end
end
