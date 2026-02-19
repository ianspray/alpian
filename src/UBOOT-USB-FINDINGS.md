# E54C U-Boot USB Findings

This document records the online/source findings gathered to explain why E54C U-Boot did not enumerate USB storage and what changes are needed.

## Scope

1. Determine whether Radxa has a rebuild path for E54C U-Boot.
2. Determine whether USB support is enabled in config.
3. Determine whether board DTS enablement gaps can still block USB at runtime.
4. Determine whether serial-console-only changes are sufficient.

## Findings

### 1) Radxa has an explicit E54C U-Boot build profile

Evidence:

1. `radxa-repo/bsp` contains a dedicated `rk2410` U-Boot profile with:
   - `BSP_GIT="https://github.com/radxa/u-boot.git"`
   - `BSP_BRANCH="next-dev-v2024.10"`
   - `SUPPORTED_BOARDS` including `radxa-e54c` and `radxa-e54c-spi`
2. Source:
   - https://github.com/radxa-repo/bsp/blob/main/u-boot/rk2410/fork.conf

Conclusion:

1. Rebuilding U-Boot for E54C is an expected and supported path in Radxa’s BSP workflow.

### 2) USB host/storage and NVMe options are already enabled in E54C SPI defconfig

Evidence:

1. `radxa/u-boot` `radxa-e54c-spi-rk3588s_defconfig` enables:
   - `CONFIG_CMD_USB=y`
   - `CONFIG_USB=y`
   - `CONFIG_USB_XHCI_HCD=y`
   - `CONFIG_USB_XHCI_DWC3=y`
   - `CONFIG_USB_STORAGE=y`
   - `CONFIG_NVME=y`
2. Source:
   - https://github.com/radxa/u-boot/blob/next-dev-v2024.10/configs/radxa-e54c-spi-rk3588s_defconfig

Conclusion:

1. USB failure is likely not from USB Kconfig being entirely disabled.

### 3) Radxa BSP common U-Boot config expects USB pre-init and NVMe boot

Evidence:

1. `bsp/u-boot/.common/kconfig.conf` includes:
   - `CONFIG_PREBOOT="usb start; pci enum"`
   - `CONFIG_CMD_NVME=y`
2. Source:
   - https://github.com/radxa-repo/bsp/blob/main/u-boot/.common/kconfig.conf

Conclusion:

1. The intended behavior is to start USB + PCI before normal boot probing.

### 4) E54C U-Boot DTS is minimal for USB enablement compared to other RK3588 boards

Evidence:

1. E54C U-Boot DTS (`rk3588s-radxa-e54c.dts`) is sparse and does not explicitly set the wider host-controller/PHY/regulator nodes used by other boards.
2. ROCK 5B+ U-Boot DTS explicitly marks multiple USB PHY/controller nodes `status = "okay"` and wires host VBUS regulators.
3. Sources:
   - E54C DTS:
     - https://github.com/radxa/u-boot/blob/next-dev-v2024.10/arch/arm/dts/rk3588s-radxa-e54c.dts
   - ROCK 5B+ DTS:
     - https://github.com/radxa/u-boot/blob/next-dev-v2024.10/arch/arm/dts/rk3588-rock-5b-plus.dts

Conclusion:

1. A DTS enablement gap is a plausible root cause for `usb start` yielding no working controllers on E54C units.

### 5) Boot-order logic supports USB-first/NVMe-second once USB is functional

Evidence:

1. U-Boot distro boot uses `boot_targets` ordering for probe sequence.
2. Source:
   - https://docs.u-boot.org/en/v2023.10/develop/distro.html

Conclusion:

1. After USB controller bring-up is fixed, `boot_targets=usb0 nvme0` is the right policy for USB-carried update media with NVMe fallback.

## Practical Implications

1. Serial console can change environment (`boot_targets`) only.
2. Serial console alone cannot permanently add missing DTS node enablement.
3. If controller bring-up is missing, fix requires:
   - DTS patch
   - U-Boot rebuild
   - SPI reflash of updated bootloader artifacts

## What Was Not Found

1. A single Radxa public guide specifically titled as “E54C USB controller fix for U-Boot no working controllers found”.
2. Therefore, this repository uses source-level comparison and board DTS patching as the deterministic approach.
