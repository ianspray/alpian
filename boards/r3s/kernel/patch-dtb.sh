#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Disable NPU nodes in the FriendlyElec RK3566 DTB for NanoPi R3S.
# The R3S has no NPU voltage supply; leaving NPU nodes enabled causes
# the rk_iommu driver to trigger a kernel panic during PM domain powerup.
set -euo pipefail

dtb_file="${1:?Usage: patch-dtb.sh <dtb_file>}"

disable_node() {
  local path="$1"
  if fdtput -t s "$dtb_file" "$path" status disabled 2>/dev/null; then
    echo "  disabled: $path"
  else
    echo "  not found (skipping): $path"
  fi
}

echo "Patching DTB for NanoPi R3S: $(basename "$dtb_file")"
disable_node /npu@fdab0000    # rknpu: NPU compute engine
disable_node /iommu@fdabc000  # rknpu_mmu: NPU IOMMU (causes panic)
disable_node /bus@fde00000    # bus_npu: NPU AXI bus
disable_node /fiq-debugger    # conflicts with ttyS2 serial console
echo "DTB patch complete."
