# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# Login shells source this twice, from profile and bashrc/zshrc.
# avoid adding its hook twice.

case $- in
*i*)
    if command -v direnv >/dev/null 2>&1; then
        if [ -n "${BASH_VERSION-}" ]; then
            eval "$(direnv hook bash)"
        elif [ -n "${ZSH_VERSION-}" ]; then
            # /etc/zshrc sources profile.d under `emulate -L ksh`, which cannot
            # parse the hook's zsh array subscripts.
            emulate zsh -c "$(direnv hook zsh)"
        fi
    fi
    ;;
esac
