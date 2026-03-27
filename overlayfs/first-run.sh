#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray

IMAGE_PART="/dev/disk/by-label/image"
ROOT_DEV="/dev/disk/by-label/root"
UPDATE_MARKER="/.update_done"
IMAGE_MARKER="/.image_partition_created"

first_boot_expand() {
    if [ -f "$IMAGE_MARKER" ]; then
        return 0
    fi
    
    echo "[first-run] Creating image partition..."
    
    root_size=$(blockdev --getsize64 "$ROOT_DEV" 2>/dev/null || echo 0)
    disk_size=$(blockdev --getsize64 /dev/disk/by-id/$(basename /dev/disk/by-path/platform-*-0.0 2>/dev/null || echo "unknown") 2>/dev/null || cat /sys/class/block/*/size 2>/dev/null | head -1)
    
    disk_name=$(lsblk -no PKNAME /dev/disk/by-label/root 2>/dev/null)
    if [ -z "$disk_name" ]; then
        for d in /dev/sd[a-z] /dev/nvme[0-9]n1 /dev/mmcblk[0]; do
            [ -b "$d" ] && disk_name=$(basename "$d") && break
        done
    fi
    
    if [ -z "$disk_name" ]; then
        echo "[first-run] Could not determine disk device"
        return 1
    fi
    
    disk_dev="/dev/$disk_name"
    last_part_num=$(ls /dev/disk/by-label/ | grep -c .)
    
    start_sector=$(cat /sys/block/$disk_name/$disk_name$((last_part_num + 1))/start 2>/dev/null || echo "0")
    
    if [ "$start_sector" = "0" ]; then
        start_sector=$(parted -s $disk_dev unit s print | grep -E "^ +[0-9]+" | tail -1 | awk '{print $2}' | sed 's/s//')
        if [ -z "$start_sector" ]; then
            echo "[first-run] Cannot determine partition start"
            return 1
        fi
    fi
    
    partprobe
    
    if [ ! -b "$IMAGE_PART" ]; then
        partdev=$(echo "$disk_dev" | sed 's|/dev/||')
        echo "n" >> /tmp/parted_input
        echo "p" >> /tmp/parted_input
        echo "" >> /tmp/parted_input
        echo "" >> /tmp/parted_input
        echo "w" >> /tmp/parted_input
        parted -s "$disk_dev" < /tmp/parted_input 2>/dev/null || true
        partprobe
    fi
    
    if [ -b "$IMAGE_PART" ]; then
        mkfs.ext4 -L image "$IMAGE_PART"
        touch "$IMAGE_MARKER"
        echo "[first-run] Image partition created successfully"
    else
        echo "[first-run] Failed to create image partition"
        return 1
    fi
}

if [ ! -f "$IMAGE_MARKER" ]; then
    first_boot_expand
fi