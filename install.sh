#!/usr/bin/env bash
set -euo pipefail

SCHEME="BuscafondosMenubar"
APP_NAME="BuscafondosMenubar.app"
DEST="/Applications/${APP_NAME}"

cd "$(dirname "$0")"

echo "▸ Regenerando proyecto con xcodegen…"
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
else
  echo "  (xcodegen no encontrado, usando .xcodeproj existente)"
fi

echo "▸ Compilando Release…"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -quiet \
  build

BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData/${SCHEME}-*/Build/Products/Release -maxdepth 1 -name "$APP_NAME" -type d | head -n 1)

if [[ -z "$BUILT_APP" ]]; then
  echo "✗ No encontré el .app compilado."
  exit 1
fi

echo "▸ Cerrando instancia corriendo (si la hay)…"
pkill -f "$SCHEME" 2>/dev/null || true
sleep 0.5

echo "▸ Copiando a /Applications…"
rm -rf "$DEST"
cp -R "$BUILT_APP" "$DEST"

echo "▸ Lanzando…"
open "$DEST"

echo "✓ Instalado en $DEST"
echo "  Buscá 'Buscafondos' en Spotlight (⌘Space) para relanzar."
