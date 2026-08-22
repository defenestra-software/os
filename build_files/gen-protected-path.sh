#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Symlink OS-critical /usr/bin names into /usr/lib/defenestra/protected.
# A layer's util-linux must not drive mounts on composefs.
set -euo pipefail

PROTECTED_PKGS=(
    util-linux-core
    util-linux
    systemd
    procps-ng
    coreutils
    shadow-utils
    sudo

    # protect dbus
    dbus-daemon
    dbus-tools
    dbus-x11
    glib2

    # fusermount3 has to have setuid so protect it
    fuse3

    # brew python3 has no gi/dnf5; fontconfig/mime/appstream caches must match
    # the system libraries that read them.
    python3
    fontconfig
    shared-mime-info
    appstream

    e2fsprogs
    keyutils
)

PROTECTED_DIR="${PROTECTED_DIR:-/usr/lib/defenestra/protected}"

install -d -m 0755 "${PROTECTED_DIR}"

count=0
for pkg in "${PROTECTED_PKGS[@]}"; do
    if ! rpm -q "${pkg}" >/dev/null 2>&1; then
        echo ":: protected-path: ${pkg} not installed, skipping"
        continue
    fi
    while read -r path; do
        [ -f "${path}" ] && [ -x "${path}" ] || continue
        ln -sfn "${path}" "${PROTECTED_DIR}/${path##*/}"
        count=$((count + 1))
    done < <(rpm -ql "${pkg}" | grep -E '^/usr/bin/[^/]+$' || true)
done

# brew's own bin/brew would break ownership. use our wrapper /usr/bin/brew
ln -sfn /usr/libexec/defenestra-brew-wrapper "${PROTECTED_DIR}/brew"

echo ":: protected-path: ${count} names pinned in ${PROTECTED_DIR} (+ brew wrapper)"
