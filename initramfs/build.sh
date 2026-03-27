#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
set -e

OUTPUT_DIR="${OUTPUT_DIR:-/output}"
BOARD="${BOARD:-rock5b}"
INITRAMFS_SRC="/build/initramfs"
CACHE_DIR="${CACHE_DIR:-/build/cache}"

echo "=== Building initramfs for: $BOARD ==="

mkdir -p "$OUTPUT_DIR/initramfs/$BOARD"
mkdir -p "$INITRAMFS_SRC/$$/bin" "$INITRAMFS_SRC/$$/sbin" "$INITRAMFS_SRC/$$/etc" "$INITRAMFS_SRC/$$/lib" "$INITRAMFS_SRC/$$/lib64" "$INITRAMFS_SRC/$$/dev" "$INITRAMFS_SRC/$$/proc" "$INITRAMFS_SRC/$$/sys" "$INITRAMFS_SRC/$$/usr/bin" "$INITRAMFS_SRC/$$/usr/sbin"

cp /build/initramfs/init "$INITRAMFS_SRC/$$/init"

for bin in sh mount umount switch_root reboot dd sha256sum zstd sync; do
    if [ -f "/bin/$bin" ]; then
        cp "/bin/$bin" "$INITRAMFS_SRC/$$/bin/"
    elif [ -f "/sbin/$bin" ]; then
        cp "/sbin/$bin" "$INITRAMFS_SRC/$$/sbin/"
    fi
done

cp -a /lib/* "$INITRAMFS_SRC/$$/lib/" 2>/dev/null || true
cp -a /lib64/* "$INITRAMFS_SRC/$$/lib64/" 2>/dev/null || true

cp -a /etc/init.d "$INITRAMFS_SRC/$$/etc/" 2>/dev/null || true
cp /build/initramfs/update-check-hook.sh "$INITRAMFS_SRC/$$/etc/" 2>/dev/null || true

mknod "$INITRAMFS_SRC/$$/dev/null" c 1 3
mknod "$INITRAMFS_SRC/$$/dev/zero" c 1 5
mknod "$INITRAMFS_SRC/$$/dev/console" c 5 1

find "$INITRAMFS_SRC/$$" -type f -name "*.so*" -exec dirname {} \; | sort -u | while read dir; do
    if [ ! -L "$dir" ]; then
        for lib in "$dir"/*.so*; do
            [ -f "$lib" ] || continue
            base=$(basename "$lib")
            if [ ! -e "$INITRAMFS_SRC/$$/lib/$base" ]; then
                ln -sf "$lib" "$INITRAMFS_SRC/$$/lib/$base" 2>/dev/null || true
            fi
        done
    fi
done

(cd "$INITRAMFS_SRC/$$" && find . | cpio -o -H newc) | gzip > "$OUTPUT_DIR/initramfs/$BOARD/initramfs"

rm -rf "$INITRAMFS_SRC/$$"

size=$(du -h "$OUTPUT_DIR/initramfs/$BOARD/initramfs" | cut -f1)
echo "=== Initramfs built: $size ==="