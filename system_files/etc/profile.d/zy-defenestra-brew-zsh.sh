# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# Put Homebrew's zsh completions on fpath.
#
# /etc/zprofile and /etc/zshrc source profile.d before ~/.zshrc, so this
# prepends ahead of the user's (or oh-my-zsh's) compinit.

if [ -n "${ZSH_VERSION-}" ] && [ -d /var/lib/defenestra/brew/zsh ]; then
    case ":${FPATH}:" in
    *:/var/lib/defenestra/brew/zsh:*) ;;
    *) FPATH="/var/lib/defenestra/brew/zsh${FPATH:+:${FPATH}}" ;;
    esac
fi
