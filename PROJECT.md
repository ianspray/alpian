# Project: e54c-alpine

## Stack
- Radxa E54C computer
  - NVMe booting
  - SPI Flash already programmed with uBoot
- Alpine Linux


## Rules
- Modifications to existing bootable images need to be done in a way that can be scripted
- Care must be taken over the booting details for the Radxa E54C
  - Partitions need to be declared at specific offsets
  - There may be binary data in the bootable image that is not inside a partition
- If anything is unclear, pause and await clarification
  - Always clearly present the problem that needs to be addressed
  - Additional discussion may be required after problem presentation before an action can be chosen
- A more modern Linux kernel is always more useful than a stock Radxa one

## Architecture
- Use a Debian AArch64 base system for constructing the initial system
- The Alpine Linux releases will always have a more recent kernel than the Radxa ones
- Not all of the Radxa kernel modules may build outside of the Rdaxa tree
- The Alpine Linux build system may be utilised if it is advantageous
  - When rebuilding via the Alpine system, the features of the Radxa kernel should be merged with that of the Alpine one
- Use of userland image manipulation tooling such as guestfish is prererable over 100% custom scripts 
- It is expected that custom scripting will be required
- The ability to take a newer version of Alpine and re-run the system in the future is a primary design aim
- When building a Linux kernel and modules, the modules should be built in a way that allows easy insertion via modprobe


## Guides
- Radxa documentation about the E54C: https://docs.radxa.com/en/e/e54c
- The Radxa guide to booting the E54C from NVMe: https://docs.radxa.com/en/e/e54c/getting-started/install-os/boot_from_nvme

## Files
- The Alpine image that should be booted on the E54C:
  - alpine-standard-3.23.3-aarch64.iso
- An Alpine image that is booted using uBoot, which may be uyseful for reference:
  - alpine-uboot-3.23.3-aarch64.tar.gz
- The official Radxa E54C Debian image:
  - radxa-e54c_bookworm_cli_b2.output.img.xz
