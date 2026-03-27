#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
set -e

OUTPUT_DIR="${OUTPUT_DIR:-/output}"
ROOTFS_DIR="${ROOTFS_DIR:-/build/rootfs}"
BOARD="${BOARD:-rock5b}"
GENIMAGE="${GENIMAGE:-genimage}"

echo "=== Building final image for: $BOARD ==="

mkdir -p "$OUTPUT_DIR/images"

GENIMAGE_CONFIG="/build/boards/$BOARD/genimage.config"

if [ ! -f "$GENIMAGE_CONFIG" ]; then
    echo "Genimage config not found: $GENIMAGE_CONFIG"
    exit 1
fi

ROOTFS_PATH="$ROOTFS_DIR/$BOARD"

if [ ! -d "$ROOTFS_PATH" ]; then
    echo "Rootfs not found: $ROOTFS_PATH"
    exit 1
fi

KERNEL_PATH="$OUTPUT_DIR/kernel/$BOARD/Image"
if [ ! -f "$KERNEL_PATH" ]; then
    echo "Kernel not found: $KERNEL_PATH"
    exit 1
fi

UBOOT_PATH="$OUTPUT_DIR/uboot/$BOARD"

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

cat > "$tmpdir/image.config" << EOF
image sdcard.img {
    gpt {
        label = "ALPIAN"
    }

    partition boot {
        partition-type = 0x0c
        offset = 17KiB
        size = 256MiB
        label = "boot"
        filesystem = "vfat"
    }

    partition root {
        partition-type = 0x83
        offset = 256MiB + 17KiB
        size = 1792MiB
        label = "root"
        filesystem = "ext4"
    }

    partition initramfs {
        partition-type = 0x83
        offset = 2048MiB + 17KiB
        size = 64MiB
        label = "initramfs"
        filesystem = "ext4"
    }

    partition image {
        partition-type = 0x83
        offset = 2112MiB + 17KiB
        size = 5880MiB
        label = "image"
        filesystem = "ext4"
    }

    file /boot/Image {
        image = "$KERNEL_PATH"
    }

    file /boot/initramfs {
        image = "$OUTPUT_DIR/initramfs/$BOARD/initramfs"
    }

    file /boot/dtb/*.dtb {
        raw = true
        include = "$OUTPUT_DIR/kernel/$BOARD/dtb/*.dtb"
    }

    file /u-boot.bin {
        raw = true
        include = "$UBOOT_PATH/u-boot.bin"
    }

    file /u-boot.itb {
        raw = true
        include = "$UBOOT_PATH/u-boot.itb"
    }
}

image rootfs.tar {
    tar {
        compression = "zstd"
    }

    file / {
        contents = "$ROOTFS_PATH"
    }
}
EOF

$GENIMAGE --rootpath="$ROOTFS_PATH" --outputpath="$OUTPUT_DIR/images" --tmppath="$tmpdir" --inputpath="$OUTPUT_DIR" --config="$tmpdir/image.config" || {
    echo "Genimage failed"
    exit 1
}

if [ -f "$OUTPUT_DIR/images/sdcard.img" ]; then
    echo "=== Image created: $OUTPUT_DIR/images/sdcard.img ==="
    ls -lh "$OUTPUT_DIR/images/sdcard.img"
fi

if [ -f "$OUTPUT_DIR/images/rootfs.tar.zst" ]; then
    echo "=== Rootfs archive created: $OUTPUT_DIR/images/rootfs.tar.zst ==="
    ls -lh "$OUTPUT_DIR/images/rootfs.tar.zst"
fi