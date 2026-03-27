#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
set -e

CACHE_DIR="${CACHE_DIR:-/build/cache}"
BOARD="${BOARD:-rock5b}"

BOARD_CONF="/build/config/${BOARD}.conf"
if [ -f "$BOARD_CONF" ]; then
    . "$BOARD_CONF"
fi

ALPINE_VERSION="${ALPINE_VERSION:-3.23.3}"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/radxa/kernel/linux-6.1-stan-rkr5.1}"
KERNEL_BRANCH="${KERNEL_BRANCH:-main}"

echo "=== Fetching assets for board: $BOARD ==="

fetch_kernel() {
    case "$BOARD" in
        rock5b|rock5c|rock5e|rock3b)
            echo "Fetching Radxa kernel $KERNEL_REPO"
            mkdir -p "$CACHE_DIR/kernel/$BOARD"
            kernel_dir=$(basename "$KERNEL_REPO")
            if [ ! -d "$CACHE_DIR/kernel/$BOARD/$kernel_dir" ]; then
                git clone --depth 1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$CACHE_DIR/kernel/$BOARD/$kernel_dir"
            fi
            ;;
        rpi4|rpi5)
            echo "Fetching upstream Linux kernel"
            mkdir -p "$CACHE_DIR/kernel/$BOARD"
            if [ ! -d "$CACHE_DIR/kernel/$BOARD/linux" ]; then
                git clone --depth 1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$CACHE_DIR/kernel/$BOARD/linux"
            fi
            ;;
    esac
}

fetch_uboot() {
    case "$BOARD" in
        rock5b|rock5c|rock5e)
            UBOOT_REPO="https://github.com/radxa-uboot/u-boot"
            echo "Fetching Radxa U-Boot"
            mkdir -p "$CACHE_DIR/uboot/$BOARD"
            if [ ! -d "$CACHE_DIR/uboot/$BOARD/u-boot" ]; then
                git clone --depth 1 --branch stable-2024.02-rk35xx "$UBOOT_REPO" "$CACHE_DIR/uboot/$BOARD/u-boot"
            fi
            ;;
        rpi4|rpi5)
            UBOOT_REPO="https://github.com/u-boot/u-boot"
            echo "Fetching upstream U-Boot"
            mkdir -p "$CACHE_DIR/uboot/$BOARD"
            if [ ! -d "$CACHE_DIR/uboot/$BOARD/u-boot" ]; then
                git clone --depth 1 --branch v2024.10 "$UBOOT_REPO" "$CACHE_DIR/uboot/$BOARD/u-boot"
            fi
            ;;
    esac
}

fetch_rootfs() {
    echo "Fetching Alpine rootfs"
    mkdir -p "$CACHE_DIR/rootfs"
    if [ ! -f "$CACHE_DIR/rootfs/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz" ]; then
        wget -q "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/aarch64/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz" \
            -O "$CACHE_DIR/rootfs/alpine-minirootfs-${ALPINE_VERSION}-aarch64.tar.gz"
    fi
}

fetch_genimage() {
    echo "Checking for genimage"
    if ! command -v genimage >/dev/null 2>&1; then
        mkdir -p "$CACHE_DIR/tools"
        if [ ! -d "$CACHE_DIR/tools/genimage" ]; then
            git clone --depth 1 https://github.com/pengutronix/genimage "$CACHE_DIR/tools/genimage"
        fi
        cd "$CACHE_DIR/tools/genimage"
        make
        make install PREFIX="$CACHE_DIR/tools/install"
    fi
}

fetch_kernel
fetch_uboot
fetch_rootfs
fetch_genimage

echo "=== Fetch complete for $BOARD ==="