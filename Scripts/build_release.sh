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

cp .build/release/notchFXApp "$STAGING/$APP_NAME.app/Contents/MacOS/notchFX"

sed \
    -e "s/@VERSION@/$VERSION/g" \
    -e "s/@BUILD@/${BUILD:-1}/g" \
    Packaging/Info.plist > "$STAGING/$APP_NAME.app/Contents/Info.plist"

echo "▶ Firmando (ad-hoc)..."
codesign --force --sign - "$STAGING/$APP_NAME.app"

ln -sf /Applications "$STAGING/Applications"

echo "▶ Creando DMG..."
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "✔ Listo: $DMG_PATH"
