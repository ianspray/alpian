#!/usr/bin/env bash
set -euo pipefail

# Ensure administrative paths are available even for non-login shells.
export PATH="$PATH:/usr/sbin:/sbin"

required_cmds=(
  git make gcc bc bison flex openssl pahole rsync cpio perl python3 awk sed
  fdisk sfdisk parted losetup blkid sgdisk gdisk kpartx
  mkfs.ext4 mkfs.vfat
  debootstrap unsquashfs xorriso isoinfo binwalk
  guestfish guestmount qemu-img mcopy mdir dtc mkimage
  dd truncate tar curl sha256sum
  podman
)

missing=()
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing required tooling:"
  printf '  - %s\n' "${missing[@]}"
  exit 1
fi

echo "All required tooling is available."
