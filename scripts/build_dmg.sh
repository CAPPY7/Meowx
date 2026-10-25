#!/bin/bash
# Builds a drag-to-Applications DMG.
# Usage: scripts/build_dmg.sh /path/to/Meowx.app 1.0.0
set -euo pipefail

APP="${1:-}"
VERSION="${2:-1.0.0}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "usage: scripts/build_dmg.sh /path/to/Meowx.app 1.0.0" >&2
  exit 1
fi
if ! command -v create-dmg >/dev/null 2>&1; then
  echo "error: create-dmg is not installed. brew install create-dmg" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/Meowx-$VERSION.dmg"
mkdir -p "$ROOT/build"
rm -f "$OUT" "$OUT.sha256"
cleanup() {
  hdiutil detach /Volumes/Meowx >/dev/null 2>&1 || true
}
trap cleanup EXIT
create-dmg \
  --volname "Meowx" \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "Meowx.app" 160 190 \
  --app-drop-link 440 190 \
  "$OUT" \
  "$APP"
(
  cd "$(dirname "$OUT")"
  shasum -a 256 "$(basename "$OUT")" | tee "$OUT.sha256"
)
echo "Wrote $OUT"
