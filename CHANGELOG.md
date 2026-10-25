# Changelog

## 1.0.4

- While a video plays, the title, traffic lights, playlist, and playback controls hide together. Settings control the delay. Audio and pause keep them visible.
- Right-click the video for play, seek, speed, audio, subtitles, full screen, and file actions. Items that are not built are not shown.
- Click pauses after a short wait, double-click enters full screen, dragging the picture moves the window, and the scroll wheel changes volume or seeks. Middle-click mutes.

## 1.0.3

- Checksum files name `Meowx-<version>.dmg` and `Meowx.dmg` instead of the Actions runner path, so `shasum -a 256 -c` works after download.

## 1.0.2

- Bundled libmpv loads on macOS 26. Duplicate Frameworks rpaths, including a trailing-slash copy, are removed before the app is signed. dyld was aborting `--self-test` with "duplicate LC_RPATH".

## 1.0.1

- The app target imports MeowxCore, so Release builds can see PlayerSettings.
- Playlist unit test no longer assigns through a shadowed constant.
- Resume store tests cover a missing file and a corrupt file.
- `--self-test` initializes libmpv, prints its version, and exits without a window.
- Screenshots report failure instead of always saying they were saved.
- HTTP media is allowed in the app transport settings.
- Release workflow verifies bundled libraries, retries the disk image, and publishes both a versioned DMG and Meowx.dmg.
- The installer checks the SHA256 before copying the app.

## 1.0.0

- First source release of Meowx for Apple Silicon on macOS 26.
- libmpv playback with VideoToolbox, playlists, subtitles, resume, streaming, stats, and a portable DMG build.
