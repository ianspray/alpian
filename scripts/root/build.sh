#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
set -e

CACHE_DIR="${CACHE_DIR:-/build/cache}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
ROOTFS_DIR="${ROOTFS_DIR:-/build/rootfs}"
BOARD="${BOARD:-rock5b}"

BOARD_CONF="/build/config/${BOARD}.conf"
if [ -f "$BOARD_CONF" ]; then
    . "$BOARD_CONF"
fi

ALPINE_VERSION="${ALPINE_VERSION:-3.23.3}"

echo "=== Building root filesystem for: $BOARD ==="

mkdir -p "$ROOTFS_DIR/$BOARD"

extract_rootfs() {
    local rootfs_tar="$CACHE_DIR/rootfs/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz"
    
    if [ ! -f "$rootfs_tar" ]; then
        echo "Rootfs tarball not found, run fetch first"
        exit 1
    fi
    
    tar -xzf "$rootfs_tar" -C "$ROOTFS_DIR/$BOARD"
}

setup_apk() {
    local rootfs="$ROOTFS_DIR/$BOARD"
    
    mkdir -p "$rootfs"/etc/apk
    echo "http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main" > "$rootfs"/etc/apk/repositories
    echo "http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community" >> "$rootfs"/etc/apk/repositories
    
    if [ -d "$OUTPUT_DIR/apk" ]; then
        mkdir -p "$rootfs"/etc/apk/keys
        cp "$OUTPUT_DIR"/apk/*.apk "$rootfs"/etc/apk/keys/ 2>/dev/null || true
    fi
}

install_kernel() {
    local rootfs="$ROOTFS_DIR/$BOARD"
    local kernel_output="$OUTPUT_DIR/kernel/$BOARD"
    
    if [ -d "$kernel_output" ]; then
        mkdir -p "$rootfs/lib/modules"
        cp -r "$kernel_output/root/lib/modules"/* "$rootfs/lib/modules/" 2>/dev/null || true
        cp "$kernel_output/Image" "$rootfs/boot/ 2>/dev/null || true
    fi
}

install_uboot() {
    local rootfs="$ROOTFS_DIR/$BOARD"
    local uboot_output="$OUTPUT_DIR/uboot/$BOARD"
    
    if [ -d "$uboot_output" ]; then
        mkdir -p "$rootfs/boot"
        cp "$uboot_output"/* "$rootfs/boot/" 2>/dev/null || true
    fi
}

install_initramfs() {
    local rootfs="$ROOTFS_DIR/$BOARD"
    
    if [ -f "$OUTPUT_DIR/initramfs/$BOARD/initramfs" ]; then
        mkdir -p "$rootfs/boot"
        cp "$OUTPUT_DIR/initramfs/$BOARD/initramfs" "$rootfs/boot/"
    fi
}

install_overlayfs_scripts() {
    local rootfs="$ROOTFS_DIR/$BOARD"
    local overlayfs_dir="/build/overlayfs"
    
    mkdir -p "$rootfs/etc"
    cp "$overlayfs_dir/overlayRoot.sh" "$rootfs/etc/" 2>/dev/null || true
    cp "$overlayfs_dir/fstab" "$rootfs/etc/" 2>/dev/null || true
    cp "$overlayfs_dir/inittab" "$rootfs/etc/" 2>/dev/null || true
}

install_custom_packages() {
    local rootfs="$ROOTFS_DIR/$BOARD"
    local packages_dir="/build/config/packages-$BOARD"
    
    if [ -d "$packages_dir" ]; then
        for apk in "$packages_dir"/*.apk; do
            [ -f "$apk" ] || continue
            cp "$apk" /tmp/
            chroot "$rootfs" /bin/sh -c "apk add --no-cache /tmp/$(basename "$apk")"
            rm -f /tmp/$(basename "$apk")
        done
    fi
}

generate_motd() {
    local rootfs="$ROOTFS_DIR/$BOARD"
    
    cat > "$rootfs/etc/motd" << 'MOTD_EOF'
Welcome to Alpian
=================
Built for aarch64 SBC appliances
MOTD_EOF
}

setup_hostname() {
    local rootfs="$ROOTFS_DIR/$BOARD"
    echo "alpian-$BOARD" > "$rootfs/etc/hostname"
}

extract_rootfs
setup_apk
install_kernel
install_uboot
install_initramfs
install_overlayfs_scripts
install_custom_packages
generate_motd
setup_hostname

echo "=== Root filesystem build complete for $BOARD ==="