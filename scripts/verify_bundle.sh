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
check_links() {
  local file="$1"
  if otool -L "$file" | grep -E '/opt/homebrew|/usr/local/'; then
    echo "non-system absolute library path in $file" >&2
    fail=1
  fi
}

check_rpaths() {
  local file="$1"
  local bad
  bad="$(otool -l "$file" | awk '
    /cmd LC_RPATH/ { flag=1; next }
    flag && $1=="path" {
      p=$2
      sub(/\/$/, "", p)
      count[p]++
      flag=0
    }
    END {
      for (k in count) if (count[k] > 1) print "duplicate", count[k], k
      for (k in count) if (k ~ /^\/opt\/homebrew/ || k ~ /^\/usr\/local/) print "homebrew-rpath", k
    }
  ')"
  if [[ -n "$bad" ]]; then
    echo "bad LC_RPATH in $file" >&2
    echo "$bad" >&2
    fail=1
  fi
}

check_links "$BINARY"
check_rpaths "$BINARY"
if [[ -d "$APP/Contents/Frameworks" ]]; then
  while IFS= read -r -d '' lib; do
    check_links "$lib"
    check_rpaths "$lib"
  done < <(find "$APP/Contents/Frameworks" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

codesign --verify --deep --strict "$APP"
if ! "$BINARY" --self-test; then
  echo "self-test failed" >&2
  ls -la "$APP/Contents/Frameworks" >&2 || true
  otool -L "$BINARY" >&2 || true
  exit 1
fi
