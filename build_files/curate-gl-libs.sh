#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build /usr/share/defenestra/opengl-driver/{lib,lib32} at image build time

set -euo pipefail
shopt -s nullglob

curate_arch() {
    local libdir="$1" outdir="$2"

    if [ ! -d "$libdir" ]; then
        echo ":: skip $libdir (not present)"
        return 0
    fi

    mkdir -p "$outdir"
    find "$outdir" -maxdepth 1 -type l -delete 2>/dev/null || true

    local tmp pat lib
    tmp="$(mktemp)"

    {
        for pat in \
            'libGLX_nvidia.so.*' 'libEGL_nvidia.so.*' \
            'libGLESv1_CM_nvidia.so.*' 'libGLESv2_nvidia.so.*' \
            'libnvidia-*.so.*' 'libcuda.so.*' 'libnvcuvid.so.*' 'libnvoptix*.so.*' \
            'libvdpau_nvidia.so.*'
        do
            for lib in $libdir/$pat; do
                if [ -e "$lib" ]; then echo "$lib"; fi
            done
        done
    } | sort -u > "$tmp"

    # ldd closure until fixed point. Only keep deps resolving inside libdir;
    # nix processes resolve everything else from their own RPATH/RUNPATH.
    # Rewrite /lib64 -> /usr/lib64 (and /lib -> /usr/lib) so the libdir
    # prefix check works against Fedora's compat symlinks. We keep the SONAME
    # (e.g. libz.so.1), NOT readlink -f's realpath (libz.so.1.3.1.zlib-ng),
    # because dlopen targets the SONAME.
    local prev=-1 cur
    cur="$(wc -l < "$tmp")"
    while [ "$cur" -ne "$prev" ]; do
        prev="$cur"
        local newtmp="${tmp}.new" dep
        cp "$tmp" "$newtmp"
        while IFS= read -r lib; do
            [ -e "$lib" ] || continue
            while IFS= read -r dep; do
                case "$dep" in
                    /lib64/*) dep="/usr/lib64/${dep#/lib64/}" ;;
                    /lib/*)   dep="/usr/lib/${dep#/lib/}" ;;
                esac
                case "$dep" in
                    "$libdir"/*) [ -e "$dep" ] && echo "$dep" ;;
                esac
            done < <(ldd "$lib" 2>/dev/null | sed -nE 's|.*=> (/[^ ]+) .*|\1|p')
        done < "$tmp" >> "$newtmp"
        sort -u "$newtmp" -o "$tmp"
        rm -f "$newtmp"
        cur="$(wc -l < "$tmp")"
    done

    # Drop the glibc/loader set. These MUST come from each nix process's own
    # toolchain; surfacing host versions corrupts the C runtime. Anchor at the
    # slash before the basename so substring matches (libcrypt, libmemkind, ...)
    # are not filtered out.
    local banned='/(libc|libpthread|libdl|libm|librt|libutil|libresolv|libnsl|libBrokenLocale|libanl|libthread_db|ld-linux[^/]*)\.so'
    grep -Ev "$banned" "$tmp" > "$tmp.f" || true
    mv "$tmp.f" "$tmp"

    # Symlink each lib under its basename. Follow symlink chains so both the
    # SONAME-style name (libfoo.so.1) and the realpath name (libfoo.so.1.2.3)
    # land in the dir -- some consumers dlopen by versioned realpath.
    local name real rname count=0
    while IFS= read -r lib; do
        [ -e "$lib" ] || continue
        name="$(basename "$lib")"
        ln -sfn "$lib" "$outdir/$name"
        if [ -L "$lib" ]; then
            real="$(readlink -f "$lib")"
            rname="$(basename "$real")"
            [ "$rname" != "$name" ] && ln -sfn "$real" "$outdir/$rname"
        fi
        count=$((count+1))
    done < "$tmp"
    rm -f "$tmp"
    echo ":: linked $count libs into $outdir"
}

curate_arch /usr/lib64 /usr/share/defenestra/opengl-driver/lib
curate_arch /usr/lib   /usr/share/defenestra/opengl-driver/lib32
