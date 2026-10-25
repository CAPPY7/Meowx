#!/bin/bash
# Installs the latest Meowx release onto an Apple Silicon Mac running macOS 26 or newer.
#   curl -fsSL https://raw.githubusercontent.com/Cappy7/Meowx/main/scripts/install.sh | bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Meowx installs on macOS only." >&2
  exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Meowx supports Apple Silicon only. This Mac is $(uname -m)." >&2
  exit 1
fi

VERSION="$(sw_vers -productVersion)"
MAJOR="${VERSION%%.*}"
if [[ "$MAJOR" -lt 26 ]]; then
  echo "Meowx requires macOS 26 or newer. This Mac is on $VERSION." >&2
  exit 1
fi

API="https://api.github.com/repos/Cappy7/Meowx/releases/latest"
URL="$(curl -fsSL "$API" | grep -o 'https://[^"]*Meowx-[^"]*\.dmg' | head -1 || true)"
if [[ -z "$URL" ]]; then
  echo "Couldn't find a Meowx DMG in the latest GitHub release." >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() {
  if [[ -n "${MOUNT:-}" ]]; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "Downloading $URL"
curl -fL "$URL" -o "$WORKDIR/Meowx.dmg"
MOUNT="$(hdiutil attach "$WORKDIR/Meowx.dmg" -nobrowse | awk '/\/Volumes\// { print substr($0, index($0, "/Volumes/")); exit }')"
if [[ -z "$MOUNT" || ! -d "$MOUNT/Meowx.app" ]]; then
  echo "The disk image did not contain Meowx.app." >&2
  exit 1
fi

DEST="/Applications/Meowx.app"
rm -rf "$DEST"
if ! cp -R "$MOUNT/Meowx.app" "$DEST"; then
  echo "Couldn't copy Meowx into /Applications. Move Meowx.app there yourself from $MOUNT" >&2
  exit 1
fi
xattr -dr com.apple.quarantine "$DEST" || true
echo "Installed $DEST"
echo "Open Meowx from Applications. If macOS blocks it, allow it under System Settings > Privacy & Security > Open Anyway."
