#!/usr/bin/env bash
# Gera o projeto do Xcode (XcodeGen), compila para o simulador de iPhone e roda os testes: os do
# app e os do núcleo compartilhado, que fica no repositório lan-cameras-mac, clonado ao lado deste.
#
#   ./scripts/compilar.sh               compila e testa
#   ./scripts/compilar.sh --sem-testes  só compila
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IRMAO="$RAIZ/../lan-cameras-mac"
testes=1
for arg in "$@"; do
  case "$arg" in
    --sem-testes) testes=0 ;;
    *) echo "opção desconhecida: $arg" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$IRMAO/Package.swift" ]]; then
  # o irmão mora no mesmo lugar que este repositório, só com o outro nome
  origem=$(git -C "$RAIZ" remote get-url origin 2>/dev/null || true)
  [[ -n "$origem" ]] || { echo "falta o lan-cameras-mac ao lado deste repositório" >&2; exit 1; }
  echo "==> Clonando o núcleo (lan-cameras-mac) ao lado deste repositório..."
  git clone --quiet "${origem/lan-cameras-ios/lan-cameras-mac}" "$IRMAO"
fi
command -v xcodegen >/dev/null || { echo "instale o XcodeGen: brew install xcodegen" >&2; exit 1; }

cd "$RAIZ"
echo "==> Gerando o projeto..."
xcodegen generate --quiet

# o primeiro iPhone disponível entre os simuladores (pelo identificador: os nomes mudam de Xcode para Xcode)
SIMULADOR=$(xcrun simctl list devices available -j | python3 -I -c '
import json, sys
d = json.load(sys.stdin)["devices"]
for runtime in sorted(d, reverse=True):
    if ".iOS-" in runtime:
        for aparelho in d[runtime]:
            if aparelho["name"].startswith("iPhone"):
                print(aparelho["udid"]); sys.exit()
')
[[ -n "$SIMULADOR" ]] || { echo "nenhum simulador de iPhone instalado (Xcode > Settings > Components)" >&2; exit 1; }

echo "==> Compilando para o simulador..."
xcodebuild -project CamerasDeCasa.xcodeproj -scheme CamerasiOS -destination "id=$SIMULADOR" \
  -derivedDataPath build/DerivedData -quiet build

if [[ $testes -eq 1 ]]; then
  echo "==> Testes do app..."
  xcodebuild -project CamerasDeCasa.xcodeproj -scheme CamerasiOS -destination "id=$SIMULADOR" \
    -derivedDataPath build/DerivedData -quiet test
  echo "==> Testes do núcleo no simulador..."
  (cd "$IRMAO" && xcodebuild -scheme CamerasCore-iOS -destination "id=$SIMULADOR" \
    -derivedDataPath "$RAIZ/build/DerivedData-nucleo" -quiet test)
fi
echo "==> Pronto: build/DerivedData/Build/Products/Debug-iphonesimulator/CamerasiOS.app"
