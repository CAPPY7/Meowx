#!/bin/bash
set -euo pipefail
if [[ -z "${BUILT_PRODUCTS_DIR:-}" || -z "${WRAPPER_NAME:-}" ]]; then
  echo "copy_ytdl_hook.sh is meant to run from Xcode" >&2
  exit 0
fi
DEST="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Contents/Resources/mpv/scripts"
mkdir -p "$DEST"
if ! command -v brew >/dev/null 2>&1; then
  exit 0
fi
PREFIX="$(brew --prefix)"
HOOK="$(find "$PREFIX/Cellar/mpv" "$PREFIX/lib" -name ytdl_hook.lua -print -quit 2>/dev/null || true)"
if [[ -n "$HOOK" ]]; then
  cp "$HOOK" "$DEST/ytdl_hook.lua"
  echo "Copied ytdl_hook.lua"
fi
