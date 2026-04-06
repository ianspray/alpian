#!/bin/sh
# -------------------------------------------------
ROOT="/src"
APK_CACHE="/etc/apk/cache"
APK_LIST="/cache/apklist.txt"

find_pkgs() {
  find "$ROOT" -type f \( -name "*.sh" -o -name "Dockerfile*" -o -name "Containerfile*" \) | while read -r f; do
    sed ':a;/\\$/N;s/\\\n/ /;ta' "$f" |
    grep -Eo 'apk[[:space:]]+add[[:space:]]+[^&|;#]*' | while read -r line; do
      echo "$line" | tr -s '[:space:]' '\n' |
      grep -v '^$' |
      grep -v '^apk$' |
      grep -v '^add$' |
      grep -v '^-' |
      grep -v '[$`/]' |
      sed 's/=.*//'
    done
  done | sort -u > ${APK_LIST}
}

fetch_pkg() {
  pkg=$1

  { echo "$pkg"; apk info --quiet --recursive --depends "$pkg" 2>/dev/null; } \
    | grep -v '^so:'  \
    | grep -v '^cmd:' \
    | grep -v '^/'    \
    | sed 's/[><=!].*//' \
    | grep -v '^$' \
    | sort -u \
    | while read -r dep; do
    [ -z "$dep" ] && continue
    if ls "${APK_CACHE}/${dep}-"*.apk 2>/dev/null | grep -q .; then
      echo "Skipping $dep (already cached)"
    else
      echo "Fetching $dep ..."
      apk fetch --output "${APK_CACHE}" "$dep"
    fi
  done
}

##########
# M A I N
#

mkdir -p "${APK_CACHE}"

apk update -q

find_pkgs
pkgs=$(cat ${APK_LIST})

[ -z "$pkgs" ] && echo "No apk packages found." && exit 0

echo "$pkgs" | while read -r p; do
    [ -n "$p" ] && fetch_pkg "$p"
done

echo ""
echo "Cached $( echo $pkgs | wc -l ) APKs in ${APK_CACHE})"

