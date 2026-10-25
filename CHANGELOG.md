# Changelog

## 1.0.14

- Volume and seek keys no longer wake the control bar. Every key used to.
- Seek-bar previews are flipped the other way. The last build was still upside down.
- YouTube and other site links use yt-dlp and ffmpeg shipped inside the app. ffmpeg is there for sites that split the picture and the sound. A copy already on the Mac is used only if the bundled one is missing.

## 1.0.13

- Volume and seek show only their readout. The control bar stays hidden.
- Dragging the time bar previews a frame and seeks once, when you let go. It no longer seeks the playing video on every move.
- Preview frames are decoded on a second player that no longer holds the video's graphics lock while it waits, and a repeated spot is reused. The picture is built so SwiftUI does not draw it upside down.

## 1.0.12

- The file name shows at the top for 4 seconds when playback starts, then goes away. It is the full file name.
- The volume knob sits on the filled part of the slider. The old white mark was fixed at the halfway point.
- Subtitle size starts at 36 with a 2 pt outline, which fits a laptop picture. A saved 55 / 1 pt pair from the first settings file is brought down to that. Size can still be changed. Styled subtitle tracks keep their own look.

## 1.0.11

- Playlist, Open, and Open URL sit on the control bar next to subtitles. They no longer float on the picture. The name of the file sits at the top left and hides with the controls.
- The bar hides while a video keeps playing, including when the pointer is resting. A small trackpad twitch no longer counts as activity. mpv's own on-video text is off.

## 1.0.10

- The playlist is a short card at the top right, not a column down the whole picture. It starts closed. Close it with the X or Esc. The top buttons stay beside it.
- Play, back 10, and forward 10 sit in the middle of the control bar. The volume slider stays next to the speaker, and the volume readout sits above the bar instead of under the playlist.

## 1.0.9

- New app icon: a white cat head with a play cutout, on a violet-to-indigo gradient. The same glyph is the empty-screen mark and the About window.
- One design token list for color, type, spacing, corners, and motion. The player window stays dark. Settings and About follow the system. Reduce Motion drops the fades. Reduce Transparency uses a solid surface instead of the thin material.
- Meowx > About Meowx shows the name, version, GPLv3, and links to the GitHub repo and license.
- The video fills the window. Showing or hiding the controls no longer resizes it. The playlist is a panel over the picture, remembered open or closed, and Esc closes it. The top bar clears the real traffic-light buttons instead of a fixed inset.
- The control bar is a short capsule: clock, seek, volume, back 10, play, forward 10, tracks, speed, more, and full screen. Loop, picture, chapters, video, screenshot, and the floating window are in More. Double-click the sides of the picture to jump 10 seconds. The middle still full-screens.
- Nothing loaded shows a home screen: drop zone, Open File, Open URL, Paste Link, continue-watching cards, and recent files. Music uses the album art. A file that will not play shows a card with Show in Finder and Remove, instead of an alert.
- Settings is a tabbed window. Playback, video, audio, and subtitle changes apply immediately. Shortcuts can be rebound, and a taken key is refused.
- Audio output device, loudness normalization, night mode, and a 10-band equalizer with presets. Media Info (Cmd+I). Update check with a release pill and no auto-install. Help copies diagnostics and shows logs, with paths hidden unless asked. Sleep timer and stop-after. Per-file audio, subtitle, delay, and zoom memory next to Continue Watching. Subtitle size on `-` and `=`, speed presets, and the chapter list.
- Controls show a hover and a pressed state, and a focus ring when you tab to them. The seek bar speaks the time and the chapter. Reduce Motion, Reduce Transparency, and Increase Contrast change the chrome in code. The playhead tick no longer rewrites values that did not change, and only the clock and the seek bar read it. English strings live in a String Catalog. Settings and About follow Dark or Match System.

## 1.0.8

- Chapters. Playback > Chapters, the seek-bar marks, the control-bar menu, and the right-click menu list them. Page Up and Page Down move between them. A file with no chapters says so, and the keys do not seek.
- Video > Flip Horizontal (Shift+R), Flip Vertical (Opt+R), Cycle Crop (Shift+E), Deinterlace (D), and Reset Zoom and Pan (G). The right-click Video menu also lists aspect and crop presets. Flip uses mpv's video filter, so it replaces any other video filter.
- Picture adjustments (C), from the sun button or Video menu: brightness, contrast, saturation, gamma, and hue, each from -100 to 100, with Reset. The values stay for the session.
- Audio output devices, normalization, a compressor, and an equalizer are not in this build.

## 1.0.7

- The end of a file advances the playlist. Repeat one, repeat all, and shuffle use that ending once, so a second end signal cannot skip an item. The resume point is cleared when the file actually finishes.
- Closing the window quits by default. Turn that off in Settings to hide the window, pause, and keep the resume point. A Dock click or an opened file brings the window back.
- The playback timer keeps running while a menu is open or the window is resizing.
- Full screen and always-on-top use the main window, not whichever panel is key.
- P opens a floating window, not system Picture in Picture. Click, Space, and the right-click menu work there, and closing it puts the video back.
- The cache size applies immediately. The slider and the saved value both stay between 64 and 2048 MB, and the backward cache stays at most 128 MB.
- Seek thumbnails are not requested for network streams, and that second player is shut down on quit.
- The window remembers its frame. Settings can size it to the video when a file opens.
- File > Open Recent and the Dock menu list recent files, with Clear Menu.
- Album art still comes from the file's tags, and falls back to an attached picture track.
- An empty file or a text file renamed as video is refused with a message. A file the player cannot decode shows the error and leaves the playlist usable.

## 1.0.6

- One key handler. Bare keys are no longer menu equivalents, so typing in Open URL, subtitle search, or Settings cannot play, mute, or switch tracks. Command shortcuts still show on the menu.
- Added 0–9 percent jumps, Home/End, subtitle and audio delay, previous track, hide subtitles, A-B loop on L, file loop on Shift+L, rotate, aspect, window size, and Ctrl+Cmd+F.
- Chapter keys are not in this build. They wait until chapters exist.

## 1.0.5

- One shortcut list drives the keys, the Help sheet, the tooltips, and the README table.
- Icon buttons name themselves and their shortcut. Playlist rows show the full path.
- Audio and subtitle menus check the current track, say when none are available, and show the delay.
- Volume, seek, speed, tracks, loop, shuffle, and screenshots show a short toast, including while the controls are hidden.

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
