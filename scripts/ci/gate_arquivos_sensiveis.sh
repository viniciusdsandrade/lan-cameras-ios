#!/usr/bin/env bash
# Nada de assinatura, chaves ou projeto gerado (que pode levar o time) entre os arquivos rastreados.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
achados=$(git ls-files | grep -E '\.(mobileprovision|provisionprofile|p12|p8|cer|keystore|jks)$|\.xcodeproj/|(^|/)ios\.env$' || true)
if [[ -n "$achados" ]]; then
  echo "FALHA: arquivos sensíveis rastreados:"; echo "$achados"; exit 1
fi
if git grep -n -E 'DEVELOPMENT_TEAM: *"?[A-Z0-9]{10}' -- project.yml >/dev/null; then
  echo "FALHA: o project.yml tem um time de assinatura; deixe DEVELOPMENT_TEAM vazio"; exit 1
fi
echo "ok: nenhum arquivo sensível rastreado"
