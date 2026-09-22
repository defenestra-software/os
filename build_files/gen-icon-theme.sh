#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
shopt -s nullglob

ADWAITA="${1:?usage: $0 <adwaita-dir> <morewaita-dir> <dest-dir>}"
MOREWAITA="${2:?usage: $0 <adwaita-dir> <morewaita-dir> <dest-dir>}"
DST="${3:?usage: $0 <adwaita-dir> <morewaita-dir> <dest-dir>}"

# name=back-face hex. "adwaita" is the unmodified upstream blue.
COLORS=(
    defenestra=5aa0c3
    defenestraorange=e9780d
    defenestraslate=64748b
    blue=3584e4
    teal=2190a4
    green=3a944a
    yellow=c88800
    orange=ed5b00
    red=e62d42
    pink=d56199
    purple=9141ac
    slate=6f8396
    adwaita=
    black=4f4f4f
    grey=8e8e8e
    white=c0bfbc
    brown=ae8e6c
    palebrown=d1bfae
    paleorange=eeca8f
    deeporange=eb6637
    carmine=a30002
    magenta=ca71df
    violet=7e57c2
    indigo=5c6bc0
    nordic=81a1c1
    bluegrey=607d8b
    cyan=00bcd4
    darkcyan=45abb7
)
DEFAULT_COLOR="defenestra"

ADW_BACK="438de6"
ADW_EDGE="62a0ea"
ADW_EDGE_SHINE1="afd4ff"
ADW_EDGE_SHINE2="c0d5ea"
ADW_FRONT="a4caee"
# MoreWaita draws some emblems (code, bitwig, nextcloud) in this off-palette blue.
MW_GLYPH="3f8ae5"
# Per mille: brand blue is lighter than Adwaita's and washes emblems out at 0.
GLYPH_SHADE=80

ADWAITA_FOLDERS=(
    folder folder-documents folder-download folder-music folder-pictures folder-publicshare
    folder-templates folder-videos folder-remote folder-drag-accept
    user-home user-desktop user-bookmarks
)

# Per mille toward white; ratios from gnome-accent-directories' Adwaita palettes.
tint() {
    local hex="$1" pm="$2" out="" i c
    for i in 0 2 4; do
        c=$((16#${hex:i:2}))
        out+="$(printf '%02x' $((c + (255 - c) * pm / 1000)))"
    done
    printf '%s' "${out}"
}

shade() {
    local hex="$1" pm="$2" out="" i
    for i in 0 2 4; do
        out+="$(printf '%02x' $((16#${hex:i:2} * (1000 - pm) / 1000)))"
    done
    printf '%s' "${out}"
}

recolor() {
    local back="$1" glyph
    shift
    glyph="$(shade "${back}" "${GLYPH_SHADE}")"
    sed -z -i \
        -e ':glyph' \
        -e "s/\(#${ADW_FRONT}.*\)#${ADW_BACK}/\1#${glyph}/I" \
        -e 't glyph' \
        -e "s/#${MW_GLYPH}/#${glyph}/gI" \
        -e "s/#${ADW_BACK}/#${back}/gI" \
        -e "s/#${ADW_EDGE}/#$(tint "${back}" 135)/gI" \
        -e "s/#${ADW_EDGE_SHINE1}/#$(tint "${back}" 555)/gI" \
        -e "s/#${ADW_EDGE_SHINE2}/#$(tint "${back}" 555)/gI" \
        -e "s/#${ADW_FRONT}/#$(tint "${back}" 487)/gI" \
        "$@"
}

# folder -> folder-red
# folder-code -> folder-red-code
# user-home -> user-red-home
colored_name() {
    local name="$1" color="$2"
    case "${name}" in
    folder) printf 'folder-%s' "${color}" ;;
    folder-*) printf 'folder-%s-%s' "${color}" "${name#folder-}" ;;
    user-*) printf 'user-%s-%s' "${color}" "${name#user-}" ;;
    esac
}

# Exact-hex recolor
for f in "${ADWAITA}/scalable/places/folder.svg" "${MOREWAITA}/scalable/places/folder-projects.svg"; do
    for hex in "${ADW_BACK}" "${ADW_EDGE}" "${ADW_FRONT}"; do
        if ! grep -qi "#${hex}" "${f}"; then
            echo "!! ${f} no longer uses #${hex}; update the folder palette" >&2
            exit 1
        fi
    done
done

rm -rf "${DST}"
mkdir -p "${DST}/scalable/places" "${DST}/scalable/mimetypes" "${DST}/scalable/status"

sources=()
for name in "${ADWAITA_FOLDERS[@]}"; do
    sources+=("${ADWAITA}/scalable/places/${name}.svg")
done
for f in "${MOREWAITA}"/scalable/places/folder-*.svg; do
    [[ "${f}" == *-legacy.svg ]] && continue
    sources+=("${f}")
done

default_back=""
for entry in "${COLORS[@]}"; do
    color="${entry%%=*}"
    back="${entry#*=}"
    [[ "${color}" == "${DEFAULT_COLOR}" ]] && default_back="${back}"
    colored=()
    for f in "${sources[@]}"; do
        name="$(basename "${f}" .svg)"
        out="${DST}/scalable/places/$(colored_name "${name}" "${color}").svg"
        cp "${f}" "${out}"
        colored+=("${out}")
    done
    if [[ -n "${back}" ]]; then
        recolor "${back}" "${colored[@]}"
    fi
done

# Uncolored names resolve to the default color.
for f in "${sources[@]}"; do
    name="$(basename "${f}" .svg)"
    ln -s "$(colored_name "${name}" "${DEFAULT_COLOR}").svg" "${DST}/scalable/places/${name}.svg"
done
ln -s ../places/folder.svg "${DST}/scalable/mimetypes/inode-directory.svg"

cp "${ADWAITA}/scalable/status/folder-open.svg" "${DST}/scalable/status/folder-open.svg"
if [[ -n "${default_back}" ]]; then
    recolor "${default_back}" "${DST}/scalable/status/folder-open.svg"
fi

cat >"${DST}/index.theme" <<'EOF'
[Icon Theme]
Name=Defenestra
Comment=MoreWaita with folders in Defenestra colors
Inherits=MoreWaita,Adwaita,AdwaitaLegacy,hicolor
Example=folder
Directories=scalable/places,scalable/mimetypes,scalable/status

[scalable/places]
Context=Places
Size=128
MinSize=8
MaxSize=512
Type=Scalable

[scalable/mimetypes]
Context=MimeTypes
Size=128
MinSize=8
MaxSize=512
Type=Scalable

[scalable/status]
Context=Status
Size=128
MinSize=8
MaxSize=512
Type=Scalable
EOF

cp "${MOREWAITA}/LICENSE" "${DST}/LICENSE"
gtk-update-icon-cache -q -f "${DST}"
