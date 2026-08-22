# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# Put the shared linuxbrew prefix on PATH for login shells (TTY, SSH).
# systemd --user gets the same via environment.d/92-defenestra-brew.conf.
#
# Strip-and-prepend: upstream brew.sh already appended the prefix for
# interactive shells; a presence guard would skip those and leave
# interactive/non-interactive PATHs disagreeing.

if [ -d /home/linuxbrew/.linuxbrew/bin ]; then
    _dbrew_new=""
    _dbrew_ifs=$IFS
    IFS=:
    for _dbrew_p in $PATH; do
        case $_dbrew_p in
            /home/linuxbrew/.linuxbrew/bin|/home/linuxbrew/.linuxbrew/sbin) continue ;;
        esac
        _dbrew_new="${_dbrew_new:+$_dbrew_new:}$_dbrew_p"
    done
    IFS=$_dbrew_ifs
    unset _dbrew_p _dbrew_ifs

    PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${_dbrew_new}"
    unset _dbrew_new
    export PATH
fi
