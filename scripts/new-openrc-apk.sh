#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APORTS_GROUP="${APORTS_GROUP:-e54c}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/new-openrc-apk.sh <package-name> <service-name>

Example:
  scripts/new-openrc-apk.sh e54c-openrc-foo e54c-foo
USAGE
}

if [ "$#" -ne 2 ]; then
  usage >&2
  exit 1
fi

pkgname="$1"
svcname="$2"

case "$pkgname" in
  *[!a-z0-9-]*|'')
    echo "Invalid package name: $pkgname" >&2
    exit 1
    ;;
esac
case "$svcname" in
  *[!a-z0-9-]*|'')
    echo "Invalid service name: $svcname" >&2
    exit 1
    ;;
esac

pkgdir="$REPO_ROOT/apk/aports/$APORTS_GROUP/$pkgname"
if [ -e "$pkgdir" ]; then
  echo "Package already exists: $pkgdir" >&2
  exit 1
fi

mkdir -p "$pkgdir"

cat >"$pkgdir/$svcname.initd" <<EOF2
#!/sbin/openrc-run

name="$svcname"
description="$svcname service"
command="/usr/libexec/$svcname"
command_background="no"

depend() {
  need localmount
  before networking
}

start() {
  ebegin "Running $svcname"
  "\$command"
  eend \$?
}
EOF2

cat >"$pkgdir/$svcname.confd" <<EOF2
# Configuration for $svcname
message="$svcname executed"
EOF2

cat >"$pkgdir/$svcname.sh" <<EOF2
#!/bin/sh
set -eu

[ -f /etc/conf.d/$svcname ] && . /etc/conf.d/$svcname
msg="\${message:-$svcname executed}"

echo "\$msg" >/dev/console 2>/dev/null || true
logger -t "$svcname" "\$msg" 2>/dev/null || true
EOF2

chmod +x "$pkgdir/$svcname.initd" "$pkgdir/$svcname.sh"

initd_sha="$(sha512sum "$pkgdir/$svcname.initd" | awk '{print $1}')"
confd_sha="$(sha512sum "$pkgdir/$svcname.confd" | awk '{print $1}')"
script_sha="$(sha512sum "$pkgdir/$svcname.sh" | awk '{print $1}')"

cat >"$pkgdir/APKBUILD" <<EOF2
# Maintainer: IWS <iws@toothless.local>
pkgname=$pkgname
pkgver=0.1.0
pkgrel=0
pkgdesc="$svcname OpenRC service"
url="https://example.invalid/e54c-alpine"
arch="aarch64"
license="MIT"
depends="openrc"
source="
  $svcname.initd
  $svcname.confd
  $svcname.sh
"
builddir="\$srcdir"
options="!check"

package() {
  install -Dm755 "\$srcdir"/$svcname.initd "\$pkgdir"/etc/init.d/$svcname
  install -Dm644 "\$srcdir"/$svcname.confd "\$pkgdir"/etc/conf.d/$svcname
  install -Dm755 "\$srcdir"/$svcname.sh "\$pkgdir"/usr/libexec/$svcname
}

sha512sums="
$initd_sha  $svcname.initd
$confd_sha  $svcname.confd
$script_sha  $svcname.sh
"
EOF2

echo "Created package skeleton: $pkgdir"
echo "Next: scripts/build-apk-repo.sh"
