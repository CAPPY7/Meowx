#!/bin/bash
set -euo pipefail
if [[ ! -f /opt/homebrew/include/mpv/client.h && ! -f /usr/local/include/mpv/client.h ]]; then
  echo "error: libmpv headers not found. Install them with: brew install mpv" >&2
  exit 1
fi
