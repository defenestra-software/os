# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# Put the shared linuxbrew prefix on PATH for login shells (TTY, SSH).
# systemd --user gets the same via /usr/lib/environment.d/90-defenestra-brew.conf.
# Man pages need no MANPATH: man-db derives share/man from the bin dir on PATH.
#
# Append, not prepend: /usr/bin/brew is our wrapper (it routes brew to the
# shared linuxbrew user via sudo). The real brew under the prefix must NOT
# shadow that wrapper, so the prefix goes after the system dirs. Brew-installed
# binaries still resolve; the wrapper and system tools win on name clashes.

if [ -d /home/linuxbrew/.linuxbrew/bin ]; then
    case ":${PATH}:" in
        *":/home/linuxbrew/.linuxbrew/bin:"*) ;;
        *) PATH="${PATH}:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin" ;;
    esac
    export PATH
fi
