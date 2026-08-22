#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo "0.1.0")}"
VERSION="${VERSION#v}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="notchFX"
STAGING="$ROOT/dist/staging"
DMG_PATH="$ROOT/dist/notchFX-$VERSION.dmg"

if [[ ! -f ".build/release/notchFXApp" ]]; then
    echo "▶ Compilando binario release..."
    swift build -c release
else
    echo "▶ Reusando binario existente (.build/release/notchFXApp); borra .build para recompilar."
fi

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING/$APP_NAME.app/Contents/MacOS"
mkdir -p "$STAGING/$APP_NAME.app/Contents/Resources"

cp .build/release/notchFXApp "$STAGING/$APP_NAME.app/Contents/MacOS/notchFX"

mkdir -p "$STAGING/$APP_NAME.app/Contents/Resources/adapter"
cp -R Packaging/adapter/. "$STAGING/$APP_NAME.app/Contents/Resources/adapter/"

if [[ -f "Packaging/Resources/notchFX.icns" ]]; then
    cp Packaging/Resources/notchFX.icns "$STAGING/$APP_NAME.app/Contents/Resources/"
else
    echo "⚠ Ícono no encontrado (Packaging/Resources/notchFX.icns); generando..."
    swift Scripts/make_icon.swift dist/AppIcon.iconset/icon_512x512@2x.png
    iconutil -c icns dist/AppIcon.iconset -o Packaging/Resources/notchFX.icns
    cp Packaging/Resources/notchFX.icns "$STAGING/$APP_NAME.app/Contents/Resources/"
fi

sed \
    -e "s/@VERSION@/$VERSION/g" \
    -e "s/@BUILD@/${BUILD:-1}/g" \
    Packaging/Info.plist > "$STAGING/$APP_NAME.app/Contents/Info.plist"

SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Apple Development/{print $2}' | head -1 || true)"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "▶ Firmando con identidad: $SIGN_IDENTITY"
    codesign --force --sign "$SIGN_IDENTITY" "$STAGING/$APP_NAME.app"
else
    echo "▶ Sin identidad de desarrollo disponible; firmando ad-hoc..."
    codesign --force --sign - "$STAGING/$APP_NAME.app"
fi

ln -sf /Applications "$STAGING/Applications"

echo "▶ Creando DMG..."
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo "✔ Listo: $DMG_PATH"
