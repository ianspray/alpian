#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APK_REPO_OUT="${APK_REPO_OUT:-$REPO_ROOT/build/apk-repo}"
APK_REPO_PORT="${APK_REPO_PORT:-8080}"
APK_REPO_HOST="${APK_REPO_HOST:-0.0.0.0}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Missing required command: python3" >&2
  exit 1
fi

if [ ! -d "$APK_REPO_OUT" ]; then
  echo "Repository directory does not exist: $APK_REPO_OUT" >&2
  echo "Run scripts/build-apk-repo.sh first." >&2
  exit 1
fi

echo "Serving custom APK repository"
echo "  Root:   $APK_REPO_OUT"
echo "  URL:    http://$APK_REPO_HOST:$APK_REPO_PORT/"
echo "Press Ctrl+C to stop."

exec python3 -m http.server "$APK_REPO_PORT" --bind "$APK_REPO_HOST" --directory "$APK_REPO_OUT"
