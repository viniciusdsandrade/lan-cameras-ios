#!/usr/bin/env bash
# O app fala com as câmeras por soquetes próprios (RTSP, ONVIF, DVRIP), não por URLSession:
# a segurança de transporte (ATS) não precisa de exceção nenhuma, e nenhuma é aceita.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
if grep -n -E "NSAppTransportSecurity|NSAllowsArbitraryLoads|NSExceptionDomains|NSAllowsLocalNetworking" project.yml; then
  echo "FALHA: o project.yml afrouxa o ATS; o app não precisa disso."
  exit 1
fi
echo "ok: ATS sem exceções"
