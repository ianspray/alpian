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
. ../fetch/common.sh

echo "=== Building U-Boot for: $BOARD ==="

build_uboot_rock() {
    UBOOT_DIR="$CACHE_DIR/uboot/$BOARD/u-boot"
    CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
    
    if [ ! -d "$UBOOT_DIR" ]; then
        echo "U-Boot source not found, run fetch first"
        exit 1
    fi
    
    cd "$UBOOT_DIR"
    
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
    esac
    
    make -j$(nproc) CROSS_COMPILE="$CROSS_COMPILE"
    
    mkdir -p "$OUTPUT_DIR/uboot/$BOARD"
    cp "$UBOOT_DIR/u-boot.bin" "$OUTPUT_DIR/uboot/$BOARD/"
    cp "$UBOOT_DIR/u-boot.dtb" "$OUTPUT_DIR/uboot/$BOARD/" 2>/dev/null || true
    
    echo "U-Boot build complete"
}

build_uboot_rpi() {
    UBOOT_DIR="$CACHE_DIR/uboot/$BOARD/u-boot"
    
    if [ ! -d "$UBOOT_DIR" ]; then
        echo "U-Boot source not found, run fetch first"
        exit 1
    fi
    
    cd "$UBOOT_DIR"
    
    case "$BOARD" in
        rpi4)
            make rpi_4_defconfig
            ;;
        rpi5)
            make rpi_5_defconfig
            ;;
    esac
    
    make -j$(nproc)
    
    mkdir -p "$OUTPUT_DIR/uboot/$BOARD"
    cp "$UBOOT_DIR/u-boot.bin" "$OUTPUT_DIR/uboot/$BOARD/"
    
    echo "U-Boot build complete"
}

case "$BOARD" in
    rock5b|rock5c|rock5e)
        build_uboot_rock
        ;;
    rpi4|rpi5)
        build_uboot_rpi
        ;;
esac