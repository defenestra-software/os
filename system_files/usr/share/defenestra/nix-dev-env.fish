# SPDX-License-Identifier: GPL-3.0-or-later
# defenestraOS: Nix profile pkg-config for fish. Toggle via `ujust enable-nix-dev`.
# PKG_CONFIG_PATH is not a fish path-list, so keep it a single colon string.
for d in \
    $HOME/.nix-profile/lib/pkgconfig $HOME/.nix-profile/share/pkgconfig \
    /nix/var/nix/profiles/default/lib/pkgconfig /nix/var/nix/profiles/default/share/pkgconfig
    if not string match -q -- "*:$d:*" ":$PKG_CONFIG_PATH:"
        set -gx PKG_CONFIG_PATH "$d:$PKG_CONFIG_PATH"
    end
end
