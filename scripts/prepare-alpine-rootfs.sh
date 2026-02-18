#!/usr/bin/env bash
set -euo pipefail

export PATH="$PATH:/usr/sbin:/sbin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ALPINE_BRANCH="${ALPINE_BRANCH:-v3.23}"
ALPINE_VERSION="${ALPINE_VERSION:-3.23.3}"
ALPINE_ARCH="${ALPINE_ARCH:-aarch64}"
ALPINE_MIRROR="${ALPINE_MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"

DOWNLOAD_DIR="${DOWNLOAD_DIR:-$REPO_ROOT/build/downloads}"
ROOTFS_DIR="${ROOTFS_DIR:-$REPO_ROOT/build/alpine-rootfs}"
ROOTFS_TAR="${ROOTFS_TAR:-$REPO_ROOT/build/alpine-rootfs.tar}"

mkdir -p "$DOWNLOAD_DIR" "$ROOTFS_DIR"

MINIROOTFS="alpine-minirootfs-${ALPINE_VERSION}-${ALPINE_ARCH}.tar.gz"
MINIROOTFS_URL="${ALPINE_MIRROR}/${ALPINE_BRANCH}/releases/${ALPINE_ARCH}/${MINIROOTFS}"
MINIROOTFS_PATH="${DOWNLOAD_DIR}/${MINIROOTFS}"

if [ ! -f "$MINIROOTFS_PATH" ]; then
  echo "Downloading $MINIROOTFS_URL"
  curl -fL "$MINIROOTFS_URL" -o "$MINIROOTFS_PATH"
fi

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"
tar -xzf "$MINIROOTFS_PATH" -C "$ROOTFS_DIR"

cat >"$ROOTFS_DIR/etc/apk/repositories" <<EOF
${ALPINE_MIRROR}/${ALPINE_BRANCH}/main
${ALPINE_MIRROR}/${ALPINE_BRANCH}/community
EOF

cat >"$ROOTFS_DIR/etc/fstab" <<'EOF'
LABEL=config /config vfat defaults 0 2
LABEL=efi /boot/efi vfat defaults 0 2
LABEL=rootfs / ext4 defaults 0 1
EOF

mkdir -p "$ROOTFS_DIR/etc/network"
cat >"$ROOTFS_DIR/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

tar -C "$ROOTFS_DIR" -cf "$ROOTFS_TAR" .

echo "Alpine rootfs prepared:"
echo "  Rootfs dir: $ROOTFS_DIR"
echo "  Rootfs tar: $ROOTFS_TAR"

