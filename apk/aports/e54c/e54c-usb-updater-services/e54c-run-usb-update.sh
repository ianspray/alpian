#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu

PAYLOAD_FILE="/opt/e54c-updater/nvme-image.img.zst"
PAYLOAD_SHA256="/opt/e54c-updater/nvme-image.img.zst.sha256"
TARGET_NVME_DEVICE="${TARGET_NVME_DEVICE:-/dev/nvme0n1}"
ROOT_PARTLABEL_REQUIRED="${ROOT_PARTLABEL_REQUIRED:-updater-rootfs}"
TARGET_WAIT_SECONDS="${TARGET_WAIT_SECONDS:-120}"
UPDATER_EFI_MOUNT="/run/e54c-updater-efi"
LOCK_DIR="/run/e54c-usb-update.lock"
BOOT_DONE_MARKER="/run/e54c-usb-update.done"

log() {
  echo "[e54c-usb-updater] $*"
}

log "E54C USB updater image active."

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "Updater is already running; skipping."
  exit 0
fi
cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [ -f "$BOOT_DONE_MARKER" ]; then
  log "Updater already flashed image in this boot; skipping."
  exit 0
fi

if ! grep -q "root=PARTLABEL=$ROOT_PARTLABEL_REQUIRED" /proc/cmdline 2>/dev/null; then
  log "Not running from updater rootfs (expected root=PARTLABEL=$ROOT_PARTLABEL_REQUIRED)."
  exit 1
fi

resolve_root_device() {
  local src="" devname=""

  find_partlabel_devname() {
    local want="$1" uevent=""
    for uevent in /sys/class/block/*/uevent; do
      [ -f "$uevent" ] || continue
      if sed -n "s/^PARTNAME=//p" "$uevent" | grep -qx "$want"; then
        basename "$(dirname "$uevent")"
        return 0
      fi
    done
    return 1
  }

  ensure_block_node() {
    local name="$1" node="/dev/$1" devno="" major="" minor=""
    if [ -b "$node" ]; then
      printf '%s' "$node"
      return 0
    fi
    devno="$(cat "/sys/class/block/$name/dev" 2>/dev/null || true)"
    [ -n "$devno" ] || return 1
    major="${devno%:*}"
    minor="${devno#*:}"
    [ -n "$major" ] && [ -n "$minor" ] || return 1
    mknod "$node" b "$major" "$minor" 2>/dev/null || true
    [ -b "$node" ] || return 1
    printf '%s' "$node"
    return 0
  }

  devname="$(find_partlabel_devname "$ROOT_PARTLABEL_REQUIRED" || true)"
  if [ -n "$devname" ]; then
    src="$(ensure_block_node "$devname" || true)"
  fi

  if command -v findmnt >/dev/null 2>&1; then
    [ -n "$src" ] || src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
  fi

  if [ -z "$src" ]; then
    src="$(awk '$2=="/"{print $1; exit}' /proc/mounts 2>/dev/null || true)"
  fi

  if [ "$src" = "/dev/root" ] || [ "$src" = "rootfs" ] || [ "$src" = "overlay" ] || [ -z "$src" ]; then
    if [ -b "/dev/disk/by-partlabel/$ROOT_PARTLABEL_REQUIRED" ]; then
      src="$(readlink -f "/dev/disk/by-partlabel/$ROOT_PARTLABEL_REQUIRED")"
    elif command -v blkid >/dev/null 2>&1; then
      src="$(blkid -t "PARTLABEL=$ROOT_PARTLABEL_REQUIRED" -o device 2>/dev/null | head -n1 || true)"
    fi
  fi

  if [ -n "$src" ] && [ -e "$src" ]; then
    src="$(readlink -f "$src" 2>/dev/null || printf '%s' "$src")"
  fi

  printf '%s' "$src"
}

derive_efi_device_from_root() {
  local root_dev="$1" root_name="" efi_name="" parent=""

  ensure_block_node() {
    local name="$1" node="/dev/$1" devno="" major="" minor=""
    if [ -b "$node" ]; then
      printf '%s' "$node"
      return 0
    fi
    devno="$(cat "/sys/class/block/$name/dev" 2>/dev/null || true)"
    [ -n "$devno" ] || return 1
    major="${devno%:*}"
    minor="${devno#*:}"
    [ -n "$major" ] && [ -n "$minor" ] || return 1
    mknod "$node" b "$major" "$minor" 2>/dev/null || true
    [ -b "$node" ] || return 1
    printf '%s' "$node"
    return 0
  }

  root_name="$(basename "$root_dev")"
  case "$root_name" in
    sd[a-z]3|vd[a-z]3|xvd[a-z]3)
      efi_name="${root_name%3}2"
      ;;
    mmcblk*p3|nvme*n*p3)
      efi_name="${root_name%p3}p2"
      ;;
  esac

  if [ -z "$efi_name" ]; then
    parent="$(basename "$(readlink -f "/sys/class/block/$root_name/.." 2>/dev/null || true)")"
    if [ -n "$parent" ]; then
      if [ -e "/sys/class/block/${parent}2" ]; then
        efi_name="${parent}2"
      elif [ -e "/sys/class/block/${parent}p2" ]; then
        efi_name="${parent}p2"
      fi
    fi
  fi

  [ -n "$efi_name" ] || return 1
  ensure_block_node "$efi_name"
}

root_dev="$(resolve_root_device)"
if [ -z "$root_dev" ] || [ ! -b "$root_dev" ]; then
  log "Unable to determine root block device."
  exit 1
fi

efi_dev="$(derive_efi_device_from_root "$root_dev" || true)"

if [ ! -b "$efi_dev" ]; then
  log "Updater EFI partition not found: $efi_dev"
  exit 1
fi

if [ "$root_dev" = "${TARGET_NVME_DEVICE}p3" ] || [ "$root_dev" = "${TARGET_NVME_DEVICE}p2" ] || [ "$root_dev" = "${TARGET_NVME_DEVICE}p1" ]; then
  log "Rootfs is on target device $TARGET_NVME_DEVICE; refusing to self-overwrite."
  exit 1
fi

if [ ! -f "$PAYLOAD_FILE" ] || [ ! -f "$PAYLOAD_SHA256" ]; then
  log "Missing payload or checksum."
  exit 1
fi

i=0
while [ ! -b "$TARGET_NVME_DEVICE" ] && [ "$i" -lt "$TARGET_WAIT_SECONDS" ]; do
  i=$((i + 1))
  sleep 1
done
if [ ! -b "$TARGET_NVME_DEVICE" ]; then
  log "Target NVMe device not found after ${TARGET_WAIT_SECONDS}s: $TARGET_NVME_DEVICE"
  exit 1
fi

log "Root device: $root_dev"
log "Updater EFI partition: $efi_dev"
log "Target NVMe device: $TARGET_NVME_DEVICE"

EXTLINUX_CONF="$UPDATER_EFI_MOUNT/extlinux/extlinux.conf"
DISABLED_EXTLINUX_CONF="$UPDATER_EFI_MOUNT/extlinux/extlinux.conf.disabled"
DONE_MARKER="$UPDATER_EFI_MOUNT/UPDATE_DONE"
ROOT_EXTLINUX_PRIMARY="/boot/extlinux/extlinux.conf"
ROOT_EXTLINUX_ALT="/extlinux/extlinux.conf"
ROOTFS_RW_MOUNT="/run/e54c-updater-rootfs"
mounted_here=0
remounted_rw=0
efi_state_persist=1
existing_mountpoint="$(awk -v dev="$efi_dev" '$1==dev{print $2; exit}' /proc/mounts 2>/dev/null || true)"
if [ -n "$existing_mountpoint" ]; then
  existing_mountopts="$(awk -v dev="$efi_dev" '$1==dev{print $4; exit}' /proc/mounts 2>/dev/null || true)"
  UPDATER_EFI_MOUNT="$existing_mountpoint"
  log "Using existing EFI mountpoint: $UPDATER_EFI_MOUNT"
  case ",$existing_mountopts," in
    *,ro,*)
      if mount -o remount,rw "$UPDATER_EFI_MOUNT"; then
        remounted_rw=1
      else
        log "Warning: cannot remount EFI partition read-write; updater boot entry will not be disabled."
        efi_state_persist=0
      fi
      ;;
  esac
else
  mkdir -p "$UPDATER_EFI_MOUNT"
  mount -o rw "$efi_dev" "$UPDATER_EFI_MOUNT"
  mounted_here=1
fi
EXTLINUX_CONF="$UPDATER_EFI_MOUNT/extlinux/extlinux.conf"
DISABLED_EXTLINUX_CONF="$UPDATER_EFI_MOUNT/extlinux/extlinux.conf.disabled"
DONE_MARKER="$UPDATER_EFI_MOUNT/UPDATE_DONE"

disable_root_extlinux() {
  local f=""
  local rel=""
  local src=""

  if [ ! -f "$ROOT_EXTLINUX_PRIMARY" ] && [ ! -f "$ROOT_EXTLINUX_ALT" ]; then
    return 0
  fi

  mkdir -p "$ROOTFS_RW_MOUNT"
  if ! mount -o rw "$root_dev" "$ROOTFS_RW_MOUNT" 2>/dev/null; then
    log "Warning: failed to mount updater rootfs read-write: $root_dev"
    return 0
  fi

  for f in "$ROOT_EXTLINUX_PRIMARY" "$ROOT_EXTLINUX_ALT"; do
    rel="${f#/}"
    src="$ROOTFS_RW_MOUNT/$rel"
    if [ -f "$src" ]; then
      if ! mv "$src" "${src}.disabled"; then
        log "Warning: failed to disable USB rootfs boot entry on device: $f"
      fi
    fi
  done

  sync
  umount "$ROOTFS_RW_MOUNT" || true
}

if [ -f "$DONE_MARKER" ]; then
  log "Update already completed on this USB media; skipping."
  disable_root_extlinux
  if [ "$efi_state_persist" -eq 1 ] && [ -f "$EXTLINUX_CONF" ]; then
    mv "$EXTLINUX_CONF" "$DISABLED_EXTLINUX_CONF" || log "Warning: failed to disable updater EFI extlinux entry."
  fi
  if [ "$mounted_here" -eq 1 ]; then
    umount "$UPDATER_EFI_MOUNT" || true
  fi
  exit 0
fi

log "Verifying payload checksum..."
(cd "$(dirname "$PAYLOAD_FILE")" && sha256sum -c "$(basename "$PAYLOAD_SHA256")")

log "Flashing payload to $TARGET_NVME_DEVICE (this can take several minutes)..."
dd_status_arg=""
if dd --help 2>&1 | grep -q "status=progress"; then
  dd_status_arg="status=progress"
fi
flash_payload() {
  if [ -n "$dd_status_arg" ]; then
    zstd -dc "$PAYLOAD_FILE" | dd of="$TARGET_NVME_DEVICE" bs=8M iflag=fullblock conv=fsync "$dd_status_arg"
  else
    zstd -dc "$PAYLOAD_FILE" | dd of="$TARGET_NVME_DEVICE" bs=8M iflag=fullblock conv=fsync
  fi
}

flash_payload &
flash_pid=$!
while kill -0 "$flash_pid" 2>/dev/null; do
  log "Flashing in progress..."
  sleep 5
done
wait "$flash_pid"
sync
touch "$BOOT_DONE_MARKER"

if command -v partprobe >/dev/null 2>&1; then
  partprobe "$TARGET_NVME_DEVICE" || true
fi

if command -v udevadm >/dev/null 2>&1; then
  udevadm settle || true
fi

log "Disabling USB updater boot entries so next boot falls through to NVMe..."
disable_root_extlinux
if [ "$efi_state_persist" -eq 1 ]; then
  if [ -f "$EXTLINUX_CONF" ]; then
    if ! mv "$EXTLINUX_CONF" "$DISABLED_EXTLINUX_CONF"; then
      log "Warning: failed to disable updater extlinux entry."
    fi
  fi
  if ! date -u +"updated:%Y-%m-%dT%H:%M:%SZ target:$TARGET_NVME_DEVICE" >"$DONE_MARKER"; then
    log "Warning: failed to write UPDATE_DONE marker."
  fi
else
  log "Warning: EFI partition is read-only; leaving updater entry enabled on USB media."
fi
sync
if [ "$remounted_rw" -eq 1 ]; then
  mount -o remount,ro "$UPDATER_EFI_MOUNT" || true
fi
if [ "$mounted_here" -eq 1 ]; then
  umount "$UPDATER_EFI_MOUNT" || true
fi

log "Update complete. Rebooting into NVMe image."
sleep 2
exec /sbin/reboot -f
