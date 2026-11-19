#!/bin/sh
set -e
V=$(cat VERSION)
PKG=deb/potmpv
rm -rf deb
mkdir -p "$PKG/DEBIAN" "$PKG/usr/bin" "$PKG/usr/share/potmpv" \
  "$PKG/usr/share/applications" "$PKG/usr/share/icons/hicolor/256x256/apps" \
  "$PKG/usr/share/icons/hicolor/64x64/apps"
cp mpv.conf input.conf potmpv.png potmpv64.png "$PKG/usr/share/potmpv/"
cp -r script-opts scripts fonts "$PKG/usr/share/potmpv/"
sed 's|@SHARE@|/usr/share/potmpv|' launcher.in > "$PKG/usr/bin/potmpv"
chmod 755 "$PKG/usr/bin/potmpv"
cp potmpv.desktop "$PKG/usr/share/applications/potmpv.desktop"
cp potmpv.png "$PKG/usr/share/icons/hicolor/256x256/apps/potmpv.png"
cp potmpv64.png "$PKG/usr/share/icons/hicolor/64x64/apps/potmpv.png"
cat > "$PKG/DEBIAN/control" <<CTL
Package: potmpv
Version: $V
Section: video
Priority: optional
Architecture: all
Depends: mpv
Recommends: zenity
Maintainer: lutfor183
Description: PotPlayer-like mpv front-end
 PotMPV skins mpv with a PotPlayer-style bottom bar, right-click menus,
 playlist drawer and Preferences window. Ships its own config dir so it
 never touches your existing mpv setup.
CTL
dpkg-deb --build --root-owner-group "$PKG" "dist/potmpv_${V}_all.deb"
echo "Built dist/potmpv_${V}_all.deb"
