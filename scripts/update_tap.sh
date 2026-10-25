#!/bin/bash
# Updates Cappy7/homebrew-meowx. Skips without failing when TAP_TOKEN is unset.
set -euo pipefail

if [[ -z "${TAP_TOKEN:-}" ]]; then
  echo "TAP_TOKEN is not set. The DMG was published, but the Homebrew tap was not updated."
  exit 0
fi

VERSION="${1:?version}"
SHA="${2:?sha256}"
if [[ ! "$SHA" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "sha256 is not 64 hex characters" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
git clone "https://x-access-token:${TAP_TOKEN}@github.com/Cappy7/homebrew-meowx.git" "$WORKDIR/tap"
mkdir -p "$WORKDIR/tap/Casks"
cat > "$WORKDIR/tap/Casks/meowx.rb" <<EOF
cask "meowx" do
  version "${VERSION}"
  sha256 "${SHA}"

  url "https://github.com/Cappy7/Meowx/releases/download/v#{version}/Meowx-#{version}.dmg"
  name "Meowx"
  desc "Free open source media player for macOS"
  homepage "https://github.com/Cappy7/Meowx"

  depends_on arch: :arm64
  depends_on macos: ">= :tahoe"

  app "Meowx.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Meowx.app"]
  end

  zap trash: "~/Library/Application Support/Meowx"
end
EOF

if [[ ! -f "$WORKDIR/tap/README.md" ]]; then
  printf '%s\n' '# homebrew-meowx' '' 'Homebrew cask for [Meowx](https://github.com/Cappy7/Meowx).' '' '```bash' 'brew install --cask cappy7/meowx/meowx' '```' > "$WORKDIR/tap/README.md"
fi

git -C "$WORKDIR/tap" config user.email "actions@github.com"
git -C "$WORKDIR/tap" config user.name "Meowx Release"
git -C "$WORKDIR/tap" add Casks/meowx.rb README.md
if git -C "$WORKDIR/tap" diff --cached --quiet; then
  echo "Tap already matches ${VERSION}."
  exit 0
fi
git -C "$WORKDIR/tap" commit -m "meowx ${VERSION}"
git -C "$WORKDIR/tap" push
