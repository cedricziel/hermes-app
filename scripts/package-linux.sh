#!/usr/bin/env bash
# Packages the Linux release bundle into a tar.gz and a .deb.
#
#   flutter build linux --release
#   scripts/package-linux.sh 0.1.9
#
# Output goes to build/linux-dist/. Needs dpkg-deb, so run it on Linux.
set -euo pipefail

VERSION="${1:?usage: package-linux.sh <version>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$(uname -m)" in
  x86_64)        FLUTTER_ARCH=x64;   TAR_ARCH=x86_64; DEB_ARCH=amd64 ;;
  aarch64|arm64) FLUTTER_ARCH=arm64; TAR_ARCH=arm64;  DEB_ARCH=arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

APP_ID="com.cedricziel.hermes_app"
BUNDLE="$ROOT_DIR/build/linux/$FLUTTER_ARCH/release/bundle"
DIST="$ROOT_DIR/build/linux-dist"
STAGE="$DIST/stage"

[[ -x "$BUNDLE/hermes_app" ]] || { echo "no release bundle at $BUNDLE" >&2; exit 1; }

rm -rf "$DIST"
mkdir -p "$STAGE"

tar_name="hermes-app-$VERSION-linux-$TAR_ARCH"
cp -r "$BUNDLE" "$STAGE/$tar_name"
tar -C "$STAGE" -czf "$DIST/$tar_name.tar.gz" "$tar_name"

pkg="$STAGE/deb"
mkdir -p "$pkg/DEBIAN" "$pkg/opt" "$pkg/usr/bin" \
  "$pkg/usr/share/applications" "$pkg/usr/share/icons/hicolor/512x512/apps"
cp -r "$BUNDLE" "$pkg/opt/hermes-app"
ln -s /opt/hermes-app/hermes_app "$pkg/usr/bin/hermes-app"
cp "$ROOT_DIR/design/icon-512.png" "$pkg/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"

cat > "$pkg/usr/share/applications/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Hermes
Comment=Client for the Hermes Agent dashboard
Exec=hermes-app
Icon=$APP_ID
Categories=Network;Chat;
Terminal=false
EOF

cat > "$pkg/DEBIAN/control" <<EOF
Package: hermes-app
Version: $VERSION
Architecture: $DEB_ARCH
Maintainer: Cedric Ziel <cedric.ziel@gmail.com>
Section: net
Priority: optional
Depends: libgtk-3-0 | libgtk-3-0t64, libsecret-1-0, libjsoncpp25 | libjsoncpp26
Description: Client for the Hermes Agent dashboard
 Sign in to a self-hosted Hermes Agent server and chat with the agent.
EOF

dpkg-deb --build --root-owner-group "$pkg" "$DIST/hermes-app_${VERSION}_$DEB_ARCH.deb"

rm -rf "$STAGE"
ls -l "$DIST"
