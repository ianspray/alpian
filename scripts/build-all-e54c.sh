#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/check-tooling.sh"
"$SCRIPT_DIR/build-apk-repo.sh"
"$SCRIPT_DIR/build-kernel-e54c.sh"
"$SCRIPT_DIR/prepare-alpine-rootfs.sh"
"$SCRIPT_DIR/assemble-e54c-image.sh"
