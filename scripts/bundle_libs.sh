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

HELPERS="$APP/Contents/Helpers"
mkdir -p "$HELPERS"
curl -fL --retry 3 -o "$HELPERS/yt-dlp" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
chmod 755 "$HELPERS/yt-dlp"
magic="$(xxd -p -l 4 "$HELPERS/yt-dlp" || true)"
case "$magic" in
  504b*)
    tmp="$(mktemp -d)"
    unzip -q "$HELPERS/yt-dlp" -d "$tmp"
    packed="$(find "$tmp" -type f \( -name 'yt-dlp*' -o -perm -111 \) | head -1)"
    if [[ -z "$packed" ]]; then
      echo "error: yt-dlp zip had no binary" >&2
      exit 1
    fi
    mv "$packed" "$HELPERS/yt-dlp"
    chmod 755 "$HELPERS/yt-dlp"
    rm -rf "$tmp"
    ;;
  cffaedfe|cefaedfe|cafebabe|2321*) ;;
  *)
    echo "error: downloaded yt-dlp is not a binary (magic $magic)" >&2
    exit 1
    ;;
esac

for tool in ffmpeg ffprobe; do
  source_bin="$(command -v "$tool")"
  cp "$source_bin" "$HELPERS/$tool"
  chmod 755 "$HELPERS/$tool"
  # Keep these libraries out of Contents/Frameworks. That folder belongs to
  # libmpv, and mixing the two ffmpeg builds makes the app abort on launch.
  mkdir -p "$HELPERS/lib"
  dylibbundler -od -b -x "$HELPERS/$tool" -d "$HELPERS/lib" -p @executable_path/lib -s "$SEARCH"
  rewrite_rpaths "$HELPERS/$tool"
done

HOOK_DEST="$APP/Contents/Resources/mpv/scripts/ytdl_hook.lua"
mkdir -p "$(dirname "$HOOK_DEST")"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cp "$ROOT/Meowx/Resources/mpv/scripts/ytdl_hook.lua" "$HOOK_DEST"

if [[ -d "$FRAMEWORKS" ]]; then
  while IFS= read -r -d '' lib; do
    rewrite_rpaths "$lib"
  done < <(find "$FRAMEWORKS" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)
fi

while IFS= read -r -d '' lib; do
  codesign --force --sign - "$lib"
done < <(find "$FRAMEWORKS" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)
if [[ -d "$HELPERS/lib" ]]; then
  while IFS= read -r -d '' lib; do
    rewrite_rpaths "$lib"
    codesign --force --sign - "$lib"
  done < <(find "$HELPERS/lib" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)
fi
codesign --force --sign - "$HELPERS/yt-dlp" "$HELPERS/ffmpeg" "$HELPERS/ffprobe"

codesign --force --deep --sign - "$APP"
echo "Bundled and ad-hoc signed $APP"
