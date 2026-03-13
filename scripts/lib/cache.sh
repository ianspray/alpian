#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

cache_init() {
  CACHE_ROOT="${CACHE_ROOT:-$REPO_ROOT/build/cache}"
  DOWNLOAD_DIR="${DOWNLOAD_DIR:-$CACHE_ROOT/downloads}"
  GIT_CACHE_DIR="${GIT_CACHE_DIR:-$CACHE_ROOT/git}"
  APK_CACHE_DIR="${APK_CACHE_DIR:-$CACHE_ROOT/apk}"
  DISTFILES_CACHE_DIR="${DISTFILES_CACHE_DIR:-$CACHE_ROOT/distfiles}"

  mkdir -p "$CACHE_ROOT" "$DOWNLOAD_DIR" "$GIT_CACHE_DIR" "$APK_CACHE_DIR" "$DISTFILES_CACHE_DIR"
}

download_cached_url() {
  local url="$1"
  local path="$2"
  local label="${3:-asset}"
  local force="${4:-0}"
  local tmp_path=""

  mkdir -p "$(dirname "$path")"

  if [ -f "$path" ] && [ "$force" != "1" ]; then
    echo "Using cached $label: $path"
    return 0
  fi

  echo "Downloading $label:"
  echo "  URL:  $url"
  echo "  PATH: $path"

  tmp_path="${path}.tmp.$$"
  rm -f "$tmp_path"
  if ! curl -fL --retry 3 --retry-delay 2 "$url" -o "$tmp_path"; then
    rm -f "$tmp_path"
    echo "Failed to download $label: $url" >&2
    return 1
  fi
  mv -f "$tmp_path" "$path"
}

cache_key_for_string() {
  local input="$1"
  printf '%s' "$input" | sha256sum | awk '{print $1}'
}

git_mirror_dir_for_repo() {
  local repo_url="$1"
  local repo_name key

  repo_name="$(basename "$repo_url")"
  repo_name="${repo_name%.git}"
  key="$(cache_key_for_string "$repo_url")"
  printf '%s/%s-%s.git\n' "$GIT_CACHE_DIR" "$repo_name" "${key:0:12}"
}

ensure_git_mirror() {
  local repo_url="$1"
  local mirror_dir="$2"
  local branch="${3:-}"

  mkdir -p "$(dirname "$mirror_dir")"

  if [ ! -d "$mirror_dir" ]; then
    echo "Creating cached git mirror:"
    echo "  REPO:   $repo_url"
    echo "  MIRROR: $mirror_dir"
    if [ -n "$branch" ]; then
      git clone --bare --branch "$branch" --single-branch "$repo_url" "$mirror_dir"
      git -C "$mirror_dir" symbolic-ref HEAD "refs/heads/$branch"
      return 0
    fi
    git clone --bare "$repo_url" "$mirror_dir"
    return 0
  fi

  if git -C "$mirror_dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$mirror_dir" remote set-url origin "$repo_url"
  else
    git -C "$mirror_dir" remote add origin "$repo_url"
  fi
  echo "Refreshing cached git mirror:"
  echo "  REPO:   $repo_url"
  echo "  MIRROR: $mirror_dir"
  if [ -n "$branch" ]; then
    git -C "$mirror_dir" fetch --prune origin \
      "+refs/heads/$branch:refs/heads/$branch"
    git -C "$mirror_dir" symbolic-ref HEAD "refs/heads/$branch"
  else
    git -C "$mirror_dir" fetch --prune origin
  fi
}

sync_git_checkout_from_cache() {
  local repo_url="$1"
  local branch="$2"
  local checkout_dir="$3"
  local mirror_dir="$4"

  if [ -d "$checkout_dir/.git" ]; then
    git -C "$checkout_dir" remote set-url origin "$mirror_dir"
    git -C "$checkout_dir" fetch --prune origin
  else
    rm -rf "$checkout_dir"
    git clone --reference-if-able "$mirror_dir" "$mirror_dir" "$checkout_dir"
  fi

  git -C "$checkout_dir" checkout -f -B "$branch" "origin/$branch"
}
