#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/check-tooling.sh"
"$SCRIPT_DIR/build-apk-repo.sh"
"$SCRIPT_DIR/build-kernel.sh"
"$SCRIPT_DIR/prepare-alpian-rootfs.sh"
"$SCRIPT_DIR/assemble-image.sh"
