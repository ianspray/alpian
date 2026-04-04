# These APK's will be added to just the rpi4 board image
apk add --no-scripts --allow-untrusted \
  --cache-dir /etc/apk/cache \
  --repository ${BUILD_DIR}/apk/alpian \
  --repository ${BUILD_DIR}/apk/${BOARD} \
  --root ${ROOTFS} \
  partition-mount-service
