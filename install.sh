#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/potmpv"
BIN="${HOME}/.local/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
MODE="install"
PORTABLE=""

usage() {
  cat <<U
PotMPV $VERSION installer
  ./install.sh              install for the current user
  ./install.sh --portable D install into directory D
  ./install.sh --uninstall  remove user install (keeps config)
U
}

while [ $# -gt 0 ]; do
  case "$1" in
    --portable) MODE="portable"; PORTABLE="${2:-}"; shift 2 ;;
    --uninstall) MODE="uninstall"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1"; usage; exit 1 ;;
  esac
done

if ! command -v mpv >/dev/null 2>&1; then
  echo "warning: mpv was not found in PATH; install mpv 0.36+ first." >&2
fi

make_launcher() {
  cat > "$1" <<'L'
#!/usr/bin/env bash
CFG="${POTMPV_CONFIG:-$HOME/.config/potmpv}"
exec mpv --config-dir="$CFG" "$@"
L
  chmod +x "$1"
}

if [ "$MODE" = "uninstall" ]; then
  rm -f "$BIN/potmpv" "$APPS/potmpv.desktop"
  echo "Removed launcher and desktop entry. Config kept at: $CONFIG"
  exit 0
fi

if [ "$MODE" = "portable" ]; then
  [ -n "$PORTABLE" ] || { echo "--portable needs a target directory" >&2; exit 1; }
  mkdir -p "$PORTABLE/config" "$PORTABLE/fonts"
  cp -f "$HERE"/mpv.conf "$HERE"/input.conf "$PORTABLE/config/"
  cp -rf "$HERE"/scripts "$HERE"/script-opts "$PORTABLE/config/"
  cp -f "$HERE"/fonts/*.ttf "$PORTABLE/fonts/" 2>/dev/null || true
  cat > "$PORTABLE/potmpv" <<'L'
#!/usr/bin/env bash
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MPV="mpv"
[ -x "$D/mpv" ] && MPV="$D/mpv"
exec "$MPV" --config-dir="$D/config" "$@"
L
  chmod +x "$PORTABLE/potmpv"
  cp -f "$HERE/README.md" "$PORTABLE/" 2>/dev/null || true
  echo "Portable install ready: $PORTABLE/potmpv"
else
  mkdir -p "$CONFIG" "$BIN" "$APPS" "$CONFIG/fonts"
  cp -f "$HERE"/mpv.conf "$HERE"/input.conf "$CONFIG/"
  cp -rf "$HERE"/scripts "$HERE"/script-opts "$CONFIG/"
  cp -f "$HERE"/fonts/*.ttf "$CONFIG/fonts/" 2>/dev/null || true
  make_launcher "$BIN/potmpv"
  cat > "$APPS/potmpv.desktop" <<D
[Desktop Entry]
Type=Application
Name=PotMPV
Comment=PotPlayer-style mpv
Exec=$BIN/potmpv %F
Terminal=false
Categories=AudioVideo;Video;Player;
Icon=mpv
MimeType=video/mp4;video/x-matroska;video/webm;video/avi;video/quicktime;audio/mpeg;audio/flac;audio/ogg;
D
  update-desktop-database "$APPS" >/dev/null 2>&1 || true
  echo "Installed PotMPV $VERSION"
  echo "  config : $CONFIG"
  echo "  launch : potmpv [file]   (or use the PotMPV menu entry)"
fi
