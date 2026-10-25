# Contributing

Meowx is GPL-3.0. By opening a pull request you agree that your contribution is licensed under GPL-3.0.

- Build on an Apple Silicon Mac with macOS 26 and `brew install mpv`.
- Keep changes to the public libmpv API. Do not copy source from VLC, IINA, or other players, and do not reuse their names or icons.
- Run `swift test --package-path Packages/MeowxCore` before a PR. Add tests for playlist and resume behavior.
- Do not commit built apps, DMGs, or `DerivedData`.
- The Homebrew cask in `homebrew-meowx/` is published from the release workflow. Bump it only when cutting a release.
