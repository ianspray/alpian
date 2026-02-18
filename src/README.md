# E54C Custom Kernel Workflow

This repository now contains a reproducible pipeline to:

1. Fetch the Radxa kernel tree with E54C DTS support.
2. Build a custom kernel, modules, and E54C DTBs.
3. Prepare an Alpine aarch64 rootfs with `apk`, `openrc`, `alpine-conf` (`lbu`), and `openssh`.
4. Assemble an NVMe-bootable raw disk image using Radxa bootloader offsets.

## Commands

Run commands from the repository root.

```bash
scripts/check-tooling.sh
scripts/build-kernel-e54c.sh
scripts/prepare-alpine-rootfs.sh
scripts/assemble-e54c-image.sh
```

One-shot pipeline:

```bash
scripts/build-all-e54c.sh
```

Flash the generated image to NVMe:

```bash
sudo scripts/write-image-to-nvme.sh --device /dev/nvme0n1
```

Non-interactive mode:

```bash
sudo scripts/write-image-to-nvme.sh --device /dev/nvme0n1 --yes
```

Safety test without writing:

```bash
sudo scripts/write-image-to-nvme.sh --device /dev/nvme0n1 --dry-run
```

## Notes

- U-Boot bootloader blobs are written at:
  - `idbloader.img` -> LBA `64`
  - `u-boot.itb` -> LBA `16384`
- Partition layout matches Radxa reference image:
  - `p1` `config` FAT32 at `16 MiB` offset, size `16 MiB`
  - `p2` `efi` FAT32, size `300 MiB`
  - `p3` `rootfs` ext4 uses remainder
- Alpine rootfs defaults:
  - Serial-only login on `ttyFIQ0` at `1500000` baud
  - `openrc` enabled for boot + networking + sshd
  - `lbu` configured with `LBU_MEDIA=config`
  - `/etc/apk/cache` points to `/media/config/cache` for persistent package cache

## Customization

- Override serial device/baud:
  - `SERIAL_TTY=ttyS2 SERIAL_BAUD=1500000 scripts/prepare-alpine-rootfs.sh`
- Override default package set:
  - `ALPINE_PACKAGES="alpine-base alpine-conf openssh curl" scripts/prepare-alpine-rootfs.sh`
- Inject root SSH authorized keys during image build:
  - `ROOT_AUTHORIZED_KEYS_FILE=/path/to/authorized_keys scripts/prepare-alpine-rootfs.sh`
