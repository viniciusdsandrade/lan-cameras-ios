#!/usr/bin/env bash
# Compila assinado com o seu time e instala no iPhone pareado (pela rede ou pelo cabo).
# Com a conta Apple gratuita a assinatura vale 7 dias: depois disso, rode de novo.
#
#   ./scripts/instalar_iphone.sh              instala e abre o app
#   ./scripts/instalar_iphone.sh --sem-abrir  só instala
#   ./scripts/instalar_iphone.sh --depurar    instala, abre com o registro (CAMERAS_DEPURAR=1) neste terminal
#
# Time e iPhone vêm de ~/.config/lan-cameras/ios.env (./scripts/preparar_ios_env.sh).
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$HOME/.config/lan-cameras/ios.env"
abrir=1
depurar=0
for arg in "$@"; do
  case "$arg" in
    --sem-abrir) abrir=0 ;;
    --depurar) depurar=1 ;;
    *) echo "opção desconhecida: $arg" >&2; exit 2 ;;
  esac
done

[[ -f "$CONFIG" ]] || { echo "rode antes: ./scripts/preparar_ios_env.sh" >&2; exit 1; }
TEAM="" UDID="" BUNDLE_ID=""
# shellcheck disable=SC1090
source "$CONFIG"
[[ -n "$TEAM" && -n "$UDID" ]] || { echo "faltam TEAM ou UDID em $CONFIG" >&2; exit 1; }
BUNDLE="${BUNDLE_ID:-com.lancameras.ios}"

cd "$RAIZ"
command -v xcodegen >/dev/null || { echo "instale o XcodeGen: brew install xcodegen" >&2; exit 1; }
xcodegen generate --quiet

echo "==> Compilando (Release, assinado)..."
xcodebuild -project CamerasDeCasa.xcodeproj -scheme CamerasiOS -configuration Release \
  -destination "id=$UDID" -derivedDataPath build/DerivedData-iphone \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" -quiet build

APP="build/DerivedData-iphone/Build/Products/Release-iphoneos/CamerasiOS.app"
echo "==> Instalando no iPhone..."
xcrun devicectl device install app --device "$UDID" "$APP" >/dev/null
echo "    instalado."

if [[ $depurar -eq 1 ]]; then
  echo "==> Abrindo com o registro do app (Ctrl+C para sair)..."
  exec xcrun devicectl device process launch --device "$UDID" --terminate-existing --console \
    --environment-variables '{"CAMERAS_DEPURAR": "1"}' "$BUNDLE"
elif [[ $abrir -eq 1 ]]; then
  xcrun devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE" >/dev/null && echo "==> Aberto no iPhone."
fi
