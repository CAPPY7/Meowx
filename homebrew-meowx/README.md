# Homebrew tap template

The installable cask is not stored here with a placeholder checksum.

`scripts/update_tap.sh` writes `Casks/meowx.rb` into [Cappy7/homebrew-meowx](https://github.com/Cappy7/homebrew-meowx) after a tagged release, using the real SHA256 of `Meowx-<version>.dmg`. That step is skipped when the `TAP_TOKEN` Actions secret is missing.
