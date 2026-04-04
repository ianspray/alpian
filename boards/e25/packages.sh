#!/bin/sh
# These APK's will be added to just the e25 board image
apk add --no-network --allow-untrusted \
  --repository=file:///apk-cache \
  --repository=file://${BUILD_DIR}/apk/alpian \
  --repository=file://${BUILD_DIR}/apk/${BOARD} \
  --root ${ROOTFS} \
  partition-mount-service \
  caddy
