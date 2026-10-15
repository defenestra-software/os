#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

# Match the GNOME Shell major in the base image. Update it at each Fedora rebase.
GNOME_SHELL_VERSION="${GNOME_SHELL_VERSION:-50}"

UUID="${1:?usage: $0 <uuid>}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/build_files/install-defenestra.sh"
EGO="https://extensions.gnome.org"

CUR="$(awk -v u="$UUID" '$1 == "install_ego_extension" && $2 == u { print $3; exit }' "$SCRIPT")"
if [ -z "${CUR:-}" ]; then
    echo "bump: ${UUID} is not pinned in ${SCRIPT}" >&2
    exit 1
fi

INFO="$(curl -fsSL "${EGO}/extension-info/?uuid=${UUID}&shell_version=${GNOME_SHELL_VERSION}")"
NEW="$(jq -r '.version' <<<"$INFO")"
if ! [[ "$NEW" =~ ^[0-9]+$ ]]; then
    echo "bump: no EGO version of ${UUID} for GNOME ${GNOME_SHELL_VERSION}" >&2
    exit 1
fi
echo "bump: ${UUID} ego=${NEW} pinned=${CUR}" >&2
if [ "$NEW" -le "$CUR" ]; then
    exit 10
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "${TMP}/ext.zip" "${EGO}/extension-data/${UUID//@/}.v${NEW}.shell-extension.zip"
SHA="$(sha256sum "${TMP}/ext.zip" | cut -d' ' -f1)"

# Pins split the version and SHA-256 across two lines.
awk -v u="$UUID" -v v="$NEW" -v s="$SHA" '
    $1 == "install_ego_extension" && $2 == u { print $1 " " u " " v " \\"; sha = 1; next }
    sha { sub(/[0-9a-f]{64}/, s); sha = 0 }
    { print }
' "$SCRIPT" > "${TMP}/script" && cat "${TMP}/script" > "$SCRIPT"

created() {
    curl -fsSL "${EGO}/api/v1/extensions/${UUID}/versions/$1/" | jq -r '.created | split(".")[0]' 2>/dev/null || echo unknown
}
CUR_DATE="$(created "$CUR")"
NEW_DATE="$(created "$NEW")"
NAME="$(jq -r '.name' <<<"$INFO")"
UPSTREAM="$(jq -r '.url // empty' <<<"$INFO")"

cat <<EOF
Bumps the [${NAME}](${EGO}$(jq -r '.link' <<<"$INFO")) pin (\`${UUID}\`) for GNOME ${GNOME_SHELL_VERSION}.

| | EGO version | Uploaded (UTC) |
|---|---|---|
| Current pin | v${CUR} | ${CUR_DATE} |
| This PR | v${NEW} | ${NEW_DATE} |

sha256 of the new zip: \`${SHA}\`
EOF
if [ -n "$UPSTREAM" ]; then
    cat <<EOF

EGO doesn't record which upstream commit a version was built from. Commits up
to the upload date: ${UPSTREAM}/commits?until=${NEW_DATE}Z
EOF
fi
