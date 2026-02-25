#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

export PATH="$PATH:/usr/sbin:/sbin"

KERNEL_REPO="${KERNEL_REPO:-https://github.com/radxa/kernel.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:-linux-6.1-stan-rkr5.1}"
KERNEL_DIR="${KERNEL_DIR:-src/radxa-kernel-e54c}"

if [ -d "$KERNEL_DIR/.git" ]; then
  echo "Refreshing existing kernel checkout in $KERNEL_DIR"
  git -C "$KERNEL_DIR" fetch --depth 1 origin "$KERNEL_BRANCH"
  git -C "$KERNEL_DIR" checkout -B "$KERNEL_BRANCH" "origin/$KERNEL_BRANCH"
else
  echo "Cloning $KERNEL_REPO ($KERNEL_BRANCH) into $KERNEL_DIR"
  git clone --depth 1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR"
fi

E54C_DTS="$KERNEL_DIR/arch/arm64/boot/dts/rockchip/rk3588s-radxa-e54c.dts"
if [ ! -f "$E54C_DTS" ]; then
  echo "Expected DTS is missing: $E54C_DTS" >&2
  exit 1
fi

echo "Kernel source ready: $(git -C "$KERNEL_DIR" rev-parse --short HEAD)"

