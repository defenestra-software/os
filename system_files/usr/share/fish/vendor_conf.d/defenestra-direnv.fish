# SPDX-License-Identifier: GPL-3.0-or-later

if status is-interactive; and command -q direnv
    direnv hook fish | source
end
