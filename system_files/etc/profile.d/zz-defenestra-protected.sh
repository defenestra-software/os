# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# Pin OS-critical binaries to their system copies for login shells (TTY, SSH).
# systemd --user gets the same via environment.d/95-defenestra-protected.conf.
#
# Strip-and-prepend: a graphical login already has this dir from environment.d,
# then zy-brew re-prepends the brew prefix in front of it; a presence guard
# no-ops there.

if [ -d /usr/lib/defenestra/protected ]; then
    _dprot_new=""
    _dprot_ifs=$IFS
    IFS=:
    for _dprot_p in $PATH; do
        case $_dprot_p in
            /usr/lib/defenestra/protected) continue ;;
        esac
        _dprot_new="${_dprot_new:+$_dprot_new:}$_dprot_p"
    done
    IFS=$_dprot_ifs
    unset _dprot_p _dprot_ifs

    PATH="/usr/lib/defenestra/protected:${_dprot_new}"
    unset _dprot_new
    export PATH
fi
