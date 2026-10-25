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

while IFS= read -r -d '' lib; do
  codesign --force --sign - "$lib"
done < <(find "$FRAMEWORKS" -name '*.dylib' -print0)

codesign --force --deep --sign - "$APP"
echo "Bundled and ad-hoc signed $APP"
