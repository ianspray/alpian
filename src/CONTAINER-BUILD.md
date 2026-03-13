# Containerized Build Guide (Debian)

This guide documents how to run board image builds in a Debian-based container, with flashing performed manually on the host.

## Scope

- Build main and USB updater images in a reproducible Linux userspace.
- Keep host-side flashing out of scope for the container.
- Support macOS hosts via Docker Desktop or Podman machine.

## Files

- Builder image definition: `Dockerfile.builder`
- Host wrapper: `scripts/build-alpian-in-container.sh`

## Prerequisites

- Install one container runtime on the host:
  - Docker (`docker`)
  - Podman (`podman`)
- Ensure the host user can run the selected runtime.
- Ensure sufficient disk space:
  - Kernel source/build output
  - Rootfs and image artifacts (`build/`)
  - Container image layers

## Quick Start

From repo root:

```bash
scripts/build-alpian-in-container.sh
```

Build for ROCK5B:

```bash
BOARD=rock5b scripts/build-alpian-in-container.sh --runtime podman
```

Build for ROCK3B:

```bash
BOARD=rock3b scripts/build-alpian-in-container.sh --runtime podman
```

Build for Raspberry Pi 4:

```bash
BOARD=rpi4 scripts/build-alpian-in-container.sh --runtime podman
```

This will:

1. Build `localhost/alpian-builder:bookworm` from `Dockerfile.builder` if missing.
2. Start a privileged container with the repo bind-mounted at `/workspace`.
3. Run `make images` inside the container, with `libguestfs` forced to the direct backend and TCG.
4. Write artifacts to host `build/` through the bind mount.
5. Use `BOARD` from the host environment (default: `e54c`).

Because the repo is bind-mounted into the builder, the shared fetch cache at `build/cache/` also persists across container runs on macOS/Linux hosts.

## Common Commands

Preferred partial-build pattern:

```bash
scripts/build-alpian-in-container.sh -- make <target>
```

This keeps the container workflow aligned with the `Makefile` dependency graph and stamp/hash reuse. Direct script invocation inside the container is still possible, but it bypasses `make` target handling and should only be used when you intentionally want to force a script to run.

Build APK repository only:

```bash
scripts/build-alpian-in-container.sh -- make apk-repo
```

Build rootfs only:

```bash
scripts/build-alpian-in-container.sh -- make rootfs
```

Build main image only:

```bash
scripts/build-alpian-in-container.sh -- make main-image
```

Build ROCK5B main image only:

```bash
BOARD=rock5b scripts/build-alpian-in-container.sh --runtime podman -- make main-image
```

Build ROCK3B main image only:

```bash
BOARD=rock3b scripts/build-alpian-in-container.sh --runtime podman -- make main-image
```

Build Raspberry Pi 4 main image only:

```bash
BOARD=rpi4 scripts/build-alpian-in-container.sh --runtime podman -- make main-image
```

Force rebuild of builder image:

```bash
scripts/build-alpian-in-container.sh --rebuild-image
```

Select runtime explicitly:

```bash
scripts/build-alpian-in-container.sh --runtime docker
scripts/build-alpian-in-container.sh --runtime podman
```

Use a custom image tag:

```bash
scripts/build-alpian-in-container.sh --image-tag localhost/alpian-builder:local
```

Expected output image names:

- E54C:
  - `build/e54c-alpian-custom.img`
  - `build/e54c-alpian-usb-updater.img`
- ROCK5B:
  - `build/rock5b-alpian-custom.img`
  - `build/rock5b-alpian-usb-updater.img`
- ROCK3B:
  - `build/rock3b-alpian-custom.img`
  - `build/rock3b-alpian-usb-updater.img`
- Raspberry Pi 4:
  - `build/rpi4-alpian-custom.img`
  - `build/rpi4-alpian-usb-updater.img`

Notes by board:

- `e54c`, `rock5b`, `rock3b`: Rockchip flow with SPI U-Boot assets + extlinux boot entries.
- `rpi4`: Alpine Raspberry Pi prebuilt boot/kernel assets + Pi firmware boot (`config.txt`/`cmdline.txt`), no SPI U-Boot injection.

## Why Privileged Mode Is Required

The build pipeline uses Linux-native image and block tooling (`guestfish`, partition/mkfs tooling, loop-backed operations) and runs `podman` for APK repo generation. Running with `--privileged` is the most reliable way to support these operations inside the builder container.

The wrapper also sets `LIBGUESTFS_BACKEND=direct` and `LIBGUESTFS_BACKEND_SETTINGS=force_tcg` inside the container. This avoids `qemu-system-aarch64` selecting a KVM-only GIC mode on hosts where nested containers do not expose `/dev/kvm`.

## Ownership and Permissions

By default, the wrapper attempts to `chown` generated output back to the invoking host UID/GID for:

- `build/`
- `assets/reference/alpine/custom-keys/`

Disable this behavior if desired:

```bash
scripts/build-alpian-in-container.sh --no-fix-perms
```

## Host Flashing (Manual)

Flashing images to USB or NVMe is intentionally excluded from this container workflow. Use host-side tooling after build completion.

Examples:

```bash
sudo scripts/write-image-to-nvme.sh --image build/e54c-alpian-usb-updater.img --device /dev/sdX --yes
sudo scripts/write-image-to-nvme.sh --image build/rock5b-alpian-usb-updater.img --device /dev/sdX --yes
sudo scripts/write-image-to-nvme.sh --image build/rock3b-alpian-usb-updater.img --device /dev/sdX --yes
sudo scripts/write-image-to-nvme.sh --device /dev/nvme0n1 --yes
```

On macOS, use your preferred native flashing workflow.

## Troubleshooting

- Runtime not found:
  - Install Docker or Podman, then re-run.
- Permission issues in `build/`:
  - Re-run without `--no-fix-perms`, or repair ownership manually.
- Nested Podman/APK build failures:
  - Rebuild builder image: `scripts/build-alpian-in-container.sh --rebuild-image`
  - Confirm host runtime supports privileged containers.
