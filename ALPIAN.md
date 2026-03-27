# Alpian Distro Configuration

## Project Overview
- **Name:** Alpian
- **Base:** Alpine Linux
- **Arch:** aarch64
- **Focus:** SBCs with appliance-like operation

## Target Hardware
- Radxa Rock 5B, 5C, 5E, Rock 3B
- Raspberry Pi 4, Pi 5

## Build Environment
- All builds inside containers (Podman or Docker)
- Container base image: Alpine Linux
- Split build into logical stages (ie: fetch remote assets, uboot, linux kernel & modules, apk, main root, image assembly, etc.)
- Use an outer Makefile to organise the stages to minimise buidl time
- All external assets (ie: githib pulls) should be cached lcoally so that rebuilds can be done with no internet access

## Kernel
- Custom kernel per-board (configurable)
- Initial version: `linux-6.1-stan-rkr5.1` from Radxa GitHub for Radxa boards
- For Raspberry Pi boards use the nmost recent upstream Linux Github supported version
- Kernel modules + Alpine modloop
- Custom U-Boot for boards that need it

## Storage (Early Boot)
- USB, eMMC, NVMe, microSD all probeable early

## Boot Sequence
1. **Minimal initramfs** (max 50MB) → probes hardware, checks for update
2. **If update found:** verify SHA256 → stream zstd decompress → dd to storage → mark done → reboot
3. **If no update:** continue to overlayfs runtime with OpenRC


## APK Building
- Use Alpine tooling
- Enable custom APK's to be added
- To be built as part of the standard build process
## Image Creation
- Tool: pengutronix/genimage
- Max size: 8GB
- Partition: GPT (all partitions labeled)
- Compression: zstd
- Verification: SHA256 only
- Genimage configs per board
- Create stub "update image check" script for the last item in the initramfs step which can be customised per board

## Partition Layout (Per Board)
- **Config partition:** vfat (long filenames supported), fixed size
- **Root partition:** ext4, fixed size
- **Additional partitions:** fixed sizes as needed per board
- **Final partition:** Labeled 'image', created on first boot after update, uses all remaining storage

## Root Filesystem (OverlayFS)
- **/lower:** Physical media, mounted read-only (configurable via /etc/inittab)
- **/upper:** tmpfs, max 400MB limit
- Can be remounted rw for live patching
- Reference: https://github.com/fitu996/overlayRoot.sh
- Can have any file added to the image trivially (ie: /etc/motd)
  - Adding images will require a rebuild, but the structure of the tree should be obvious
  - Prefer a static tree rather than inline HEREDOC files to add to the image
  - Also enable scripted build of a file during image build (ie: loopback mount or chroot into the data being assembled)

## Custom Packages
- Multiple APK files built from source
- Optional inclusion at build time
- Self-hosted APK repository for post-install additions
- Enable custom APK install lists per board

## Update Image
- Compression: zstd
- Verification: SHA256 checksum only
- Installation: Streaming decompression via dd

