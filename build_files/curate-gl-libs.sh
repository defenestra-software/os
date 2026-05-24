#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build /usr/share/defenestra/opengl-driver/{lib,lib32} at image build time
# by symlinking host GPU userspace + ldd-closure deps. tmpfiles wires
# /run/opengl-driver/{lib,lib32} -> these dirs at boot.
#
# Why curated instead of `L /run/opengl-driver/lib -> /usr/lib64`?
# nix-built GL apps find the entry-point driver (libGL, libvulkan_*.so) via
# the /run/opengl-driver path. But Mesa drivers have transitive deps (libLLVM,
# libz, libdrm, libelf, libzstd, ...) that nix's ld-linux can't resolve unless
# /run/opengl-driver/lib is on LD_LIBRARY_PATH. Surfacing the whole /usr/lib64
# there shadows libc/libssl/libstdc++/etc. in unrelated nix processes. A
# narrow lib dir holds only GPU userspace -> safe to expose system-wide.
#
# libstdc++.so.6 and libgcc_s.so.1 are intentionally NOT excluded. Mesa's
# libLLVM is built against Fedora's gcc; on F44 those are newer than any nix
# channel ships, so forward-compat ABI works in the direction we want.

set -euo pipefail

curate_arch() {
    local libdir="$1" outdir="$2" arch_suffix="$3"

    if [ ! -d "$libdir" ]; then
        echo ":: skip $libdir (not present)"
        return 0
    fi

    mkdir -p "$outdir"
    find "$outdir" -maxdepth 1 -type l -delete 2>/dev/null || true

    local tmp pat lib json icd
    tmp="$(mktemp)"

    {
        # Vendor-tagged GLX/EGL backends (libGLX_mesa, libGLX_nvidia, ...)
        # come along via the *_*.so.* globs. NVIDIA blobs are absent on
        # AMD/Intel hosts; unmatched globs expand to nothing here.
        for pat in \
            'libGL.so.*' 'libEGL.so.*' \
            'libGLESv1_CM.so.*' 'libGLESv2.so.*' \
            'libGLdispatch.so.*' 'libGLX.so.*' 'libOpenGL.so.*' \
            'libGLX_*.so.*' 'libEGL_*.so.*' \
            'libgbm.so.*' 'libglapi.so.*' 'libxatracker.so.*' \
            'libva.so.*' 'libva-drm.so.*' 'libva-x11.so.*' 'libva-wayland.so.*' \
            'libvdpau.so.*' 'libdrm*.so.*' \
            'libVkLayer_*.so' \
            'libnvidia-*.so.*' 'libcuda.so.*' 'libnvcuvid.so.*' 'libnvoptix*.so.*' \
            'libvdpau_nvidia.so.*'
        do
            for lib in $libdir/$pat; do
                [ -e "$lib" ] && echo "$lib"
            done
        done

        # Vulkan ICDs from the JSON manifests so every Mesa driver (radeon,
        # intel, lvp, virtio, nouveau, panvk, freedreno, asahi, ...) and any
        # vendor driver dropping a manifest gets picked up automatically.
        if [ -d /usr/share/vulkan/icd.d ]; then
            for json in /usr/share/vulkan/icd.d/*"${arch_suffix}".json; do
                [ -e "$json" ] || continue
                icd="$(sed -nE 's/.*"library_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$json" | head -1)"
                [ -z "$icd" ] && continue
                [[ "$icd" != /* ]] && icd="$libdir/$icd"
                [ -e "$icd" ] && echo "$icd"
            done
        fi
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

curate_arch /usr/lib64 /usr/share/defenestra/opengl-driver/lib   .x86_64
curate_arch /usr/lib   /usr/share/defenestra/opengl-driver/lib32 .i686
