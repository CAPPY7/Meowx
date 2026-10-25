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

BASE="https://github.com/Cappy7/Meowx/releases/latest/download"
WORKDIR="$(mktemp -d)"
MOUNT=""
cleanup() {
  if [[ -n "$MOUNT" ]]; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "Downloading Meowx"
curl -fL "$BASE/Meowx.dmg" -o "$WORKDIR/Meowx.dmg"
curl -fL "$BASE/Meowx.dmg.sha256" -o "$WORKDIR/Meowx.dmg.sha256"
HASH="$(awk 'NR == 1 { print $1 }' "$WORKDIR/Meowx.dmg.sha256")"
if [[ ! "$HASH" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "The checksum file is not a SHA256 hash." >&2
  exit 1
fi
printf '%s  %s\n' "$HASH" "$WORKDIR/Meowx.dmg" | shasum -a 256 -c -

mkdir -p "$WORKDIR/mnt"
hdiutil attach "$WORKDIR/Meowx.dmg" -nobrowse -quiet -mountpoint "$WORKDIR/mnt"
MOUNT="$WORKDIR/mnt"
if [[ ! -d "$MOUNT/Meowx.app" ]]; then
  echo "The disk image did not contain Meowx.app." >&2
  exit 1
fi

osascript -e 'tell application "Meowx" to quit' >/dev/null 2>&1 || true
DEST="/Applications/Meowx.app"
rm -rf "$DEST"
if ! cp -R "$MOUNT/Meowx.app" "$DEST"; then
  echo "Couldn't copy Meowx into /Applications." >&2
  exit 1
fi
xattr -dr com.apple.quarantine "$DEST" || true
echo "Installed $DEST"
echo "If macOS blocks the first launch, go to System Settings > Privacy & Security and click Open Anyway."
echo "Right-click > Open does not clear this warning on current macOS."
