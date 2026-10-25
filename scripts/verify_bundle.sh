#!/bin/bash
# Fails if the app still links Homebrew or /usr/local, then checks the signature and --self-test.
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "usage: scripts/verify_bundle.sh /path/to/Meowx.app" >&2
  exit 1
fi

BINARY="$APP/Contents/MacOS/Meowx"
fail=0
check() {
  local file="$1"
  if otool -L "$file" | grep -E '/opt/homebrew|/usr/local/'; then
    echo "non-system absolute library path in $file" >&2
    fail=1
  fi
}

check "$BINARY"
if [[ -d "$APP/Contents/Frameworks" ]]; then
  while IFS= read -r -d '' lib; do
    check "$lib"
  done < <(find "$APP/Contents/Frameworks" -name '*.dylib' -print0)
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

codesign --verify --deep --strict "$APP"
"$BINARY" --self-test
