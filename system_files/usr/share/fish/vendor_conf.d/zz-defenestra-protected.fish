# SPDX-License-Identifier: GPL-3.0-or-later
#
# ublue-brew.fish --move prepends the brew prefix in front of everything earlier.

if test -d /usr/lib/defenestra/protected
    fish_add_path --global --move --path /usr/lib/defenestra/protected
end
