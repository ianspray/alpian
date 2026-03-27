#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
CACHE_DIR="${CACHE_DIR:-/build/cache}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
BOARD="${BOARD:-rock5b}"

BOARD_CONF="/build/config/${BOARD}.conf"
if [ -f "$BOARD_CONF" ]; then
    . "$BOARD_CONF"
fi

ALPINE_VERSION="${ALPINE_VERSION:-3.23.3}"

cd "$(dirname "$0")"
. ../../scripts/fetch/common.sh

echo "=== Building Linux kernel for: $BOARD ==="

KERNEL_DIR="$CACHE_DIR/kernel/$BOARD"
if [ -d "$KERNEL_DIR" ]; then
    KERNEL_DIR=$(ls -d $KERNEL_DIR/*/ 2>/dev/null | head -1)
fi

build_kernel() {
    CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
    
    if [ ! -d "$KERNEL_DIR" ]; then
        echo "Kernel source not found, run fetch first"
        exit 1
    fi
    
    cd "$KERNEL_DIR"
    
    case "$BOARD" in
        rock5b)
            make rock5b_defconfig
            ;;
        rock5c)
            make rock5c_defconfig
            ;;
        rock5e)
            make rock5e_defconfig
            ;;
        rock3b)
            make rock3b_defconfig
            ;;
        rpi4|rpi5)
            make ARCH=arm64 defconfig
            ;;
    esac
    
    make -j$(nproc) ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" Image
    make -j$(nproc) ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" modules
    make -j$(nproc) ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" INSTALL_MOD_PATH="$OUTPUT_DIR/kernel/$BOARD/root" modules_install
    
    mkdir -p "$OUTPUT_DIR/kernel/$BOARD"
    cp "$KERNEL_DIR/arch/arm64/boot/Image" "$OUTPUT_DIR/kernel/$BOARD/"
    cp "$KERNEL_DIR/.config" "$OUTPUT_DIR/kernel/$BOARD/config"
    
    echo "Kernel build complete"
}

build_kernel