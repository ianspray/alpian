#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

export PATH="$PATH:/usr/sbin:/sbin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/check-tooling.sh"
"$SCRIPT_DIR/fetch-radxa-kernel.sh"

KERNEL_DIR="${KERNEL_DIR:-$REPO_ROOT/src/radxa-kernel-e54c}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/build/kernel-out}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$REPO_ROOT/build/kernel-artifacts}"
ARCH="${ARCH:-arm64}"
JOBS="${JOBS:-$(nproc)}"
DEFCONFIG_TARGET="${DEFCONFIG_TARGET:-rockchip_linux_defconfig}"
FRAGMENT_FILE="${FRAGMENT_FILE:-$REPO_ROOT/assets/reference/radxa/custom-kernel.fragment}"
BUILD_TARGETS="${BUILD_TARGETS:-Image dtbs modules}"

mkdir -p "$OUT_DIR" "$ARTIFACTS_DIR"

echo "Generating base kernel config ($DEFCONFIG_TARGET)"
make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH="$ARCH" "$DEFCONFIG_TARGET"

echo "Merging vendor rk3588 config + custom fragment"
"$KERNEL_DIR/scripts/kconfig/merge_config.sh" \
  -m -O "$OUT_DIR" \
  "$OUT_DIR/.config" \
  "$KERNEL_DIR/arch/arm64/configs/rk3588_linux.config" \
  "$FRAGMENT_FILE"

make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH="$ARCH" olddefconfig

echo "Building kernel targets: $BUILD_TARGETS (jobs=$JOBS)"
make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH="$ARCH" -j"$JOBS" $BUILD_TARGETS

KERNEL_RELEASE="$(make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH="$ARCH" -s kernelrelease)"
RELEASE_DIR="$ARTIFACTS_DIR/$KERNEL_RELEASE"

mkdir -p "$RELEASE_DIR/boot/dtbs/rockchip" "$RELEASE_DIR/rootfs"
cp "$OUT_DIR/arch/arm64/boot/Image" "$RELEASE_DIR/boot/Image"
cp "$OUT_DIR/.config" "$RELEASE_DIR/kernel.config"

for dtb in rk3588s-radxa-e54c.dtb rk3588s-radxa-e54c-spi.dtb; do
  src="$OUT_DIR/arch/arm64/boot/dts/rockchip/$dtb"
  if [ -f "$src" ]; then
    cp "$src" "$RELEASE_DIR/boot/dtbs/rockchip/$dtb"
  fi
done

if [[ " $BUILD_TARGETS " == *" modules "* ]]; then
  make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH="$ARCH" \
    modules_install INSTALL_MOD_PATH="$RELEASE_DIR/rootfs"
fi

echo "Kernel build complete."
echo "Kernel release: $KERNEL_RELEASE"
echo "Artifacts: $RELEASE_DIR"
