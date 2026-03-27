# Alpian Build System
<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Ian Spray -->

A custom Alpine Linux distribution for aarch64 SBC appliances.

## Target Boards

- Radxa Rock 5B, 5C, 5E, Rock 3B
- Raspberry Pi 4, Pi 5

## Prerequisites

- Docker or Podman installed
- At least 20GB free disk space
- Internet connection for initial build (subsequent builds can work offline with cached assets)

## Quick Start

### 1. Build the container

```bash
make container-build CONTAINER_RUNTIME=docker  # or podman
```

### 2. Run the container

```bash
make container-run CONTAINER_RUNTIME=docker
```

### 3. Inside the container, build for a specific board

```bash
make build-rock5b
```

Or build all boards:

```bash
make all-boards
```

## Build Stages

1. **fetch** - Downloads kernel, U-Boot, rootfs from remote sources
2. **uboot** - Builds U-Boot for target board
3. **kernel** - Builds Linux kernel (per-board configuration)
4. **apk** - Builds custom APK packages
5. **root** - Creates root filesystem with all components
6. **image** - Generates final disk image with genimage

## Output

Built images are located in:
- `output/images/` - Final disk images
- `output/kernel/` - Kernel and modules
- `output/uboot/` - U-Boot binaries
- `output/apk/` - Custom APK packages
- `output/initramfs/` - Initramfs images

## Custom Packages

Add custom APKBUILD files to `packages/<package-name>/` directory. The build system will automatically include them in the build.

## Configuration

- Edit `ALPIAN.md` for distro configuration
- Board-specific genimage configs in `boards/<board>/genimage.config`
- Per-board package lists in `config/packages.conf`

## Clean

```bash
make clean    # Remove build artifacts
make distclean # Remove everything including cache
```

# Licence

All code generated as part of the project is MIT licenced (see LICENCE.md).  Code that has been used from external projects will honour that licence, and those projects should be consulted for details.
