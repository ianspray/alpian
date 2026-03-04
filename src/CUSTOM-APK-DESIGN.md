# Custom APK Design for E54C

This guide describes a sustainable way to package your own tools as Alpine APKs and integrate them with this repository.

## Goals

1. Package binaries, scripts, and baseline config cleanly.
2. Keep mutable config outside package payload and persist via `lbu`.
3. Minimize runtime drift by baking known packages into image build.
4. Keep updates repeatable and rollback-friendly.

## Recommended Package Layout

Use a split-package model for each tool family:

1. `mytool`
   - Binaries and immutable assets.
   - Install to `/usr/bin`, `/usr/libexec/mytool`, `/usr/share/mytool`.
2. `mytool-openrc` (optional but recommended)
   - OpenRC service files in `/etc/init.d` and `/etc/conf.d`.
3. `mytool-defaults` (optional)
   - Ship default config templates under `/usr/share/mytool/defaults`.
   - Do not ship mutable live config as hard package state.

Why this split:

1. Immutable code stays in package-managed paths.
2. Runtime config stays under `/etc/mytool` and is operator-owned.
3. Service packaging can evolve separately from tool binaries.

## Config and `lbu` Strategy

For config that operators will change:

1. Keep live config in `/etc/mytool`.
2. Seed initial config from package defaults in `post-install` only if missing.
3. Let `apk` preserve edited `/etc` files (`.apk-new` behavior on upgrade).
4. Persist changes with `lbu commit`.

For persistent state outside `/etc` (only if needed):

1. Add explicit include paths:
   - `lbu include var/lib/mytool`
   - `lbu include root/.ssh/authorized_keys` (example)
2. Commit after changes:
   - `lbu commit`

If you need generated backup artifacts before commit, use:

1. `/etc/lbu/pre-package.d/*`
2. `/etc/lbu/post-package.d/*`

## APKBUILD Pattern

Use `abuild` tooling and include install hooks.

Minimal pattern:

```sh
pkgname=mytool
pkgver=1.0.0
pkgrel=0
pkgdesc="My E54C tool"
url="https://example.local/mytool"
arch="aarch64 x86_64"
license="MIT"
depends=""
makedepends=""
install="$pkgname.post-install"
subpackages="$pkgname-openrc"
source="mytool.bin mytool.sh mytool.post-install mytool.initd mytool.confd"

package() {
  install -Dm755 "$srcdir"/mytool.bin "$pkgdir"/usr/bin/mytool
  install -Dm755 "$srcdir"/mytool.sh "$pkgdir"/usr/libexec/mytool/helper.sh
  install -Dm644 "$srcdir"/default.yaml "$pkgdir"/usr/share/mytool/defaults/default.yaml
}

openrc() {
  pkgdesc="OpenRC service for mytool"
  depends="$pkgname"
  install_if="$pkgname=$pkgver-r$pkgrel openrc"
  amove etc/init.d/mytool
  amove etc/conf.d/mytool
}
```

`mytool.post-install` example:

```sh
#!/bin/sh
set -e

if [ ! -f /etc/mytool/config.yaml ]; then
  install -Dm644 /usr/share/mytool/defaults/default.yaml /etc/mytool/config.yaml
fi

exit 0
```

## Build and Repository Workflow

Use Alpine packaging workflow:

1. Create package skeleton (`newapkbuild`) and APKBUILD.
2. Run:
   - `abuild checksum`
   - `abuild -r`
3. Output appears under `~/packages/...` with `APKINDEX.tar.gz`.
4. Test locally with:
   - repository path in `/etc/apk/repositories`, or
   - `apk add --repository /path/to/repo mytool`

Repository tooling available in this project:

1. Place `APKBUILD` packages under `apk/aports/<namespace>/<package>/`.
2. Build/sign all packages:
   - `scripts/build-apk-repo.sh`
   - uses Podman (rootless-compatible)
3. Serve the repo for image builds:
   - `scripts/serve-apk-repo.sh`
4. Add repo URL(s) to:
   - `assets/reference/alpine/custom-repositories.txt`
5. Add package names to:
   - `assets/reference/alpine/custom-packages.txt`
6. Rebuild image:
   - `scripts/prepare-alpine-rootfs.sh`
   - `scripts/assemble-image.sh`

If a local repo exists at `build/apk-repo/v3.23`, `prepare-alpine-rootfs.sh` auto-adds it and auto-imports keys from `build/apk-repo/keys`.

## Integrating with This Repo

For packages known to be required at runtime:

1. Add package names to `assets/reference/alpine/packages.txt`.
2. Rebuild:
   - `scripts/prepare-alpine-rootfs.sh`
   - `scripts/assemble-image.sh`

This keeps runtime `lbu` data small because package payload is in the base image.

Current image runtime model:

1. Default boot is true diskless (`diskless=yes`) with root in RAM.
2. Writes are RAM-backed unless explicitly persisted.
3. Use `lbu commit` for explicit config persistence to `config` media.

For ad-hoc runtime packages:

1. `apk add ...`
2. Commit with `lbu commit` if you want package/config persistence.

## Handling Many Custom Packages

If package count grows:

1. Keep a dedicated custom repository (signed) and pin versions.
2. Keep `assets/reference/alpine/packages.txt` as your baseline world policy.
3. Avoid storing large package payload in apkovl.
4. Keep `lbu` focused on config and small state.
5. Increase persistent cache/storage as needed (config partition is currently 256 MiB).

## Versioning and Release Discipline

For each internal package release:

1. Bump `pkgrel` for packaging-only changes.
2. Bump `pkgver` for upstream/tool changes.
3. Keep changelog per package.
4. Rebuild image and test boot/network/service health before deployment.

## References

1. https://wiki.alpinelinux.org/wiki/Creating_an_Alpine_package
2. https://wiki.alpinelinux.org/wiki/APKBUILD_Reference
3. https://docs.alpinelinux.org/user-handbook/0.1a/Working/apk.html
4. https://wiki.alpinelinux.org/wiki/Alpine_local_backup
5. https://wiki.alpinelinux.org/wiki/Local_APK_cache
