#!/bin/sh
set -e
V=$(cat VERSION)
rm -rf AppDir
mkdir -p AppDir/usr/bin AppDir/usr/share/potmpv AppDir/usr/share/applications \
  AppDir/usr/share/icons/hicolor/256x256/apps AppDir/usr/share/icons/hicolor/64x64/apps
cp mpv.conf input.conf potmpv.png potmpv64.png AppDir/usr/share/potmpv/
cp -r script-opts scripts fonts AppDir/usr/share/potmpv/
sed 's|@SHARE@|/usr/share/potmpv|' launcher.in > AppDir/usr/bin/potmpv
chmod 755 AppDir/usr/bin/potmpv
cat > AppDir/AppRun <<'RUN'
#!/bin/sh
HERE=$(dirname "$(readlink -f "$0")")
SHARE="$HERE/usr/share/potmpv"
CFG="${POTMPV_CONFIG:-$HOME/.config/potmpv}"
if [ ! -f "$CFG/mpv.conf" ]; then mkdir -p "$CFG"; cp -r "$SHARE/." "$CFG/"; fi
exec mpv --config-dir="$CFG" "$@"
RUN
chmod 755 AppDir/AppRun
cp potmpv.desktop AppDir/potmpv.desktop
cp potmpv.png AppDir/potmpv.png
if [ ! -x /tmp/appimagetool ]; then
  curl -sL -o /tmp/appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x /tmp/appimagetool
fi
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 /tmp/appimagetool AppDir "dist/potmpv_${V}-x86_64.AppImage" 2>&1 | tail -3
echo "Built dist/potmpv_${V}-x86_64.AppImage"
