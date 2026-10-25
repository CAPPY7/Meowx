#!/bin/bash
# Copies libmpv and its dependencies into Meowx.app and ad-hoc signs the result.
# Usage: scripts/bundle_libs.sh /path/to/Meowx.app
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "usage: scripts/bundle_libs.sh /path/to/Meowx.app" >&2
  exit 1
fi
if ! command -v dylibbundler >/dev/null 2>&1; then
  echo "error: dylibbundler is not installed. brew install dylibbundler" >&2
  exit 1
fi

BINARY="$APP/Contents/MacOS/Meowx"
FRAMEWORKS="$APP/Contents/Frameworks"
mkdir -p "$FRAMEWORKS"
SEARCH="$(brew --prefix)/lib"
dylibbundler -od -b -x "$BINARY" -d "$FRAMEWORKS" -p @executable_path/../Frameworks -s "$SEARCH"

# dylibbundler adds @executable_path/../Frameworks even when Xcode already
# wrote that rpath. macOS 26 dyld refuses to map an image that contains the
# same LC_RPATH twice (a trailing slash counts as the same path).
rewrite_rpaths() {
  local file="$1"
  local raw line canon unique=""
  raw="$(otool -l "$file" | awk '/cmd LC_RPATH/{flag=1; next} flag && $1=="path"{print $2; flag=0}')"
  [[ -z "$raw" ]] && return 0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    install_name_tool -delete_rpath "$line" "$file"
  done <<< "$raw"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    canon="${line%/}"
    case "$canon" in
      /opt/homebrew|/opt/homebrew/*|/usr/local|/usr/local/*) continue ;;
    esac
    case " $unique " in
      *" $canon "*) continue ;;
    esac
    install_name_tool -add_rpath "$canon" "$file"
    unique="$unique $canon"
  done <<< "$raw"
}

rewrite_rpaths "$BINARY"
if [[ -d "$FRAMEWORKS" ]]; then
  while IFS= read -r -d '' lib; do
    rewrite_rpaths "$lib"
  done < <(find "$FRAMEWORKS" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)
fi

while IFS= read -r -d '' lib; do
  codesign --force --sign - "$lib"
done < <(find "$FRAMEWORKS" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)

codesign --force --deep --sign - "$APP"
echo "Bundled and ad-hoc signed $APP"
