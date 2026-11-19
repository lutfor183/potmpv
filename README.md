# PotMPV

PotPlayer-style controls for mpv: bottom control bar, right-click menus, playlist
drawer and a Preferences window, plus PotPlayer-like defaults. Pure Lua scripts;
no external binaries, no background services, no web UI.

## Requirements

- mpv 0.36 or newer (0.37 tested)
- Linux, Windows or macOS
- Mouse (keyboard still works for everything)

## Install

### Linux

```sh
./install.sh            # per-user install (config in ~/.config/potmpv)
./install.sh --uninstall
./install.sh --portable /media/usb/PotMPV   # self-contained folder
```

Launch with `potmpv FILE` or the "PotMPV" application entry. Your existing
`~/.config/mpv` setup (uosc, etc.) is untouched.

### Windows

1. Download an mpv Windows build and unpack it to `dist\win\mpv` (or let
   `build-windows.ps1` do it).
2. Run `install.ps1` (PowerShell) for a per-user install, or
   `install.ps1 -Portable D:\PotMPV` for a portable folder.
3. Build the setup with `build-windows.ps1` (requires Inno Setup 6).

`install.ps1 -Uninstall` removes the launcher and shortcut, keeping settings.

### Packages

```sh
./build.sh            # portable tarball -> dist/potmpv-<version>-portable.tar.gz
./build-deb.sh        # Debian/Ubuntu -> dist/potmpv_<version>_all.deb
./build-appimage.sh   # AppImage     -> dist/potmpv_<version>-x86_64.AppImage
```

The .deb installs to `/usr` (`potmpv` on PATH). The AppImage is single-file.
Both seed `~/.config/potmpv` on first run and never touch `~/.config/mpv`.

```sh
./install.sh            # per-user install (config in ~/.config/potmpv)
./install.sh --uninstall
./install.sh --portable /media/usb/PotMPV   # self-contained folder
```

## What you get

- PotPlayer-like bottom bar: prev/play/next/stop/open, time, seek strip with
  hover time, volume slider, speed, AUD/SUB buttons, playlist, settings,
  fullscreen. Auto-hides after 2.5 s; reappears on mouse move.
- Right-click menu: Open file/folder/URL, aspect ratio, playlist, playback,
  video, audio, subtitles, controls, screenshots. Submenus open on hover,
  arrow keys work, long lists scroll. The menu keeps a fixed readable size on
  small windows and never flickers.
- Single left click on the video toggles play/pause (double click toggles
  fullscreen and keeps the previous state).
- Online subtitle search: Subtitle > Find subtitles online (OpenSubtitles API
  v1). Set `osub_api_key`, `osub_user`, `osub_pass` in
  `script-opts/pot.conf` (or export `OPENSUBTITLES_API_KEY`).
- Controls submenu opens input.conf / mpv.conf / pot.conf in your editor.
- Auto-load folder: opening a video appends its sibling videos to the playlist
  (toggle in Playlist menu). Save playlist as .m3u from the same menu.
- Preferences window (F5): playback, video, audio, subtitles, screenshots and
  interface options with live apply and reset.
- Playlist drawer (F6 or bar button) with current-item highlight, scrolling,
  auto-load of the current folder and .m3u export.
- Defaults tuned for low CPU/GPU load: hardware decoding, no interpolation, no
  deband, audio-synced playback.

## Hotkeys

| Key | Action |
| --- | --- |
| Space | Play / pause |
| Enter, F | Fullscreen |
| Esc | Leave fullscreen |
| Left/Right | Seek 5 s |
| Shift/Ctrl + Left/Right | Seek 30 s |
| Up/Down, 9/0 | Volume |
| M | Mute |
| `[` / `]` | Speed -/+ 0.1 |
| Backspace | Speed 1.0 |
| PageUp/PageDown | Previous/next playlist item |
| S | Screenshot |
| J / # | Next subtitle / audio track |
| V | Toggle subtitles |
| T | Always on top |
| F5 | Preferences |
| F6 | Playlist |
| Ctrl+O / Ctrl+U | Open file / URL |
| Ctrl+Q | Quit |
| I | Stats |
| `~` | Console |

Mouse: left = play/pause (bar buttons clickable), double-left = fullscreen,
middle = playlist, right = menu, wheel = volume, Shift+wheel = seek,
Ctrl+wheel = speed.

## Skin options

`script-opts/pot.conf`:

```ini
font=            # empty = Segoe UI on Windows, Roboto elsewhere
scale=1.0        # bar/menu scale
accent=3E9BD8    # accent colour (RRGGBB)
bar_alpha=E8     # bar background alpha (00-FF)
hide_delay=2500  # auto-hide delay in ms
playlist_width=360
```

## Layout

```
mpv.conf            PotPlayer-like defaults
input.conf          key/mouse map
scripts/pot_ui.lua  bottom bar + playlist drawer
scripts/pot_menu.lua right-click menus and dialogs
scripts/pot_prefs.lua Preferences window
script-opts/pot.conf skin options
fonts/              bundled Roboto (UI + subtitles)
install.sh          Linux installer
install.ps1         Windows installer
build.sh            portable Linux archive
build-windows.ps1   Windows setup builder (Inno Setup)
installer/          Inno Setup script
```

## Troubleshooting

- Bar/menu not visible: check `mpv --version` is 0.36+ and that `osc=no` is not
  overridden elsewhere.
- Verify script load errors: run `mpv --config-dir=~/.config/potmpv --idle` and
  read the terminal.
- No hardware decoding on some drivers: set `hwdec=no` in `mpv.conf`.
- URLs need `yt-dlp` on PATH for streaming sites.

## Repository

<https://github.com/lutfor183/potmpv>

## License

MIT. Inspired by PotPlayer and by ReinPlayer (feature ideas only; no code or
assets copied).
