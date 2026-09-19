#!/usr/bin/env bash
# Regenerates every platform icon from the SVGs in this directory.
# Needs rsvg-convert and ImageMagick (`brew install librsvg imagemagick`).
set -euo pipefail

cd "$(dirname "$0")/.."
D=design

png() { rsvg-convert -w "$2" -h "$2" "$D/$1" -o "$3"; }

# iOS: full-bleed square, no alpha (the App Store rejects transparency).
IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
for f in "$IOS"/Icon-App-*.png; do
  name=$(basename "$f" .png)
  size=${name#Icon-App-}; scale=${size#*@}; scale=${scale%x}; size=${size%%@*}; size=${size%%x*}
  px=$(python3 -c "print(round($size*$scale))")
  png icon.svg "$px" "$f"
  magick "$f" -background '#3F35B8' -alpha remove -alpha off "$f"
done

# macOS: rounded tile inset on a transparent canvas.
MAC=macos/Runner/Assets.xcassets/AppIcon.appiconset
for px in 16 32 64 128 256 512 1024; do png icon-macos.svg "$px" "$MAC/app_icon_$px.png"; done

# Android: legacy launcher icons plus adaptive foreground/background.
RES=android/app/src/main/res
i=0
for spec in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  IFS=: read -r dpi legacy adaptive <<<"$spec"
  png icon.svg "$legacy" "$RES/mipmap-$dpi/ic_launcher.png"
  png icon-foreground.svg "$adaptive" "$RES/mipmap-$dpi/ic_launcher_foreground.png"
done

# Windows: multi-size .ico.
TMP=$(mktemp -d)
for px in 16 24 32 48 64 128 256; do png icon.svg "$px" "$TMP/$px.png"; done
magick "$TMP"/16.png "$TMP"/24.png "$TMP"/32.png "$TMP"/48.png "$TMP"/64.png "$TMP"/128.png "$TMP"/256.png \
  windows/runner/resources/app_icon.ico
rm -rf "$TMP"

# Play Store / marketing copy.
png icon.svg 512 "$D/icon-512.png"
