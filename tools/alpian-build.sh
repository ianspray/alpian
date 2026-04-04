#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray
#
# NB: rebuild the alpian-builder container after making changes to this files to
# ensure that the changes are available to use on subsequent build commands
set -e

ALPINE_VER="v3.23"
CACHE_DIR="/cache"
BOARDS_DIR="/boards"
BUILD_DIR="/build"
WORK_DIR="/work"
OUT_DIR="/out"

source "${BOARDS_DIR}/${BOARD}/${BOARD}.env"

LINUX_SRC="${CACHE_DIR}/linux/${KERNEL_DIR}/kernel"
UBOOT_SRC="${CACHE_DIR}/u-boot/${UBOOT_DIR}/u-boot"
APORTS_SRC="${BUILD_DIR}/aports"

ROOTFS="${WORK_DIR}/rootfs"

####################
# F U N C T I O N S
#

setup_builder() {
  echo "setup_builder()"
  mkdir -p ${BUILD_DIR}/apk
  chmod 777 ${BUILD_DIR}/apk
  install -d -m 700 -o builder -g builder /home/builder/.abuild
  cp -f "${APORTS_SRC}/abuild.rsa" /home/builder/.abuild/
  cp -f "${APORTS_SRC}/abuild.rsa.pub" /home/builder/.abuild/
  echo 'PACKAGER_PRIVKEY="/home/builder/.abuild/abuild.rsa"' > /home/builder/.abuild/abuild.conf
  echo 'REPODEST="/build/apk"' >> /home/builder/.abuild/abuild.conf
  chown builder:builder /home/builder/.abuild/*
  cp -f "${APORTS_SRC}/abuild.rsa.pub" /etc/apk/keys

  # remove any stale indexes that would cause signature mismatch
  rm -f "${BUILD_DIR}/apk/alpian/aarch64/APKINDEX.tar.gz"
  rm -f "${BUILD_DIR}/apk/${BOARD}/aarch64/APKINDEX.tar.gz"

  # re-create indexes signed with the correct key if packages exist
  for dir in "${BUILD_DIR}/apk/alpian/aarch64" "${BUILD_DIR}/apk/${BOARD}/aarch64"; do
    mkdir -p "$dir"
    if ls "$dir"/*.apk 2>/dev/null | grep -q .; then
      apk index -o "$dir/APKINDEX.tar.gz" "$dir"/*.apk
      abuild-sign -k "${APORTS_SRC}/abuild.rsa" "$dir/APKINDEX.tar.gz"
    fi
  done

  # keep standard alpine repos for dependency resolution
  # /etc/apk/cache is already bind-mounted with the pre-fetched .apk files
  # so network hits will be avoided for anything already cached
  cat > /etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VER}/main
https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VER}/community
${BUILD_DIR}/apk/alpian
${BUILD_DIR}/apk/${BOARD}
EOF
}

build_aports() {
  echo "build_aports()"
  for APKBUILD in ${APORTS_SRC}/alpian/*/APKBUILD ${APORTS_SRC}/${BOARD}/*/APKBUILD; do
    if [ -f "${APKBUILD}" ]; then
      PKG_DIR="$(dirname ${APKBUILD})"
      PKG_NAME="$(basename ${PKG_DIR})"
      echo "Building '${PKG_NAME}'..."
      su -s /bin/sh builder -c "abuild-pkg.sh ${PKG_DIR}" 2>&1 || echo "Failed to build '${PKG_NAME}'"
    fi
  done
}

build_linux() {
  echo "build_linux()"
}

build_uboot() {
  echo "build_uboot()"
}

build_rootfs() {
  echo "build_rootfs()"
  mkdir -p "${ROOTFS}/etc/apk"
  apk --root ${ROOTFS} add --initdb
  cp /etc/apk/repositories $ROOTFS/etc/apk
  # add the packages common for all boards
  echo "Common..."
  source ${BOARDS_DIR}/common/packages.sh
  # add the packages that this specific device wants
  echo "${BAORD}..."
  source ${BOARDS_DIR}/${BOARD}/packages.sh
  # copy in any tree of files that is always to be present
  echo cp -a ${BUILD_DIR}/rootfs-overlay/* ${ROOTFS}/
  cp -a ${BUILD_DIR}/rootfs-overlay/* ${ROOTFS}/
}

build_bootfs() {
  echo "build_bootfs"
}

build_image() {
  echo "build_image()"
}

##########
# M A I N
#
setup_builder
build_aports
build_rootfs
