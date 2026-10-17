#!/usr/bin/env bash
# O manifesto de privacidade existe, é um plist válido, não rastreia e não coleta nada.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
M="Resources/PrivacyInfo.xcprivacy"
[[ -f "$M" ]] || { echo "FALHA: falta $M"; exit 1; }
if command -v plutil >/dev/null; then plutil -lint "$M" >/dev/null; fi
python3 -I - "$M" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], "rb"))
assert d.get("NSPrivacyTracking") is False, "NSPrivacyTracking deve ser false"
assert d.get("NSPrivacyTrackingDomains", []) == [], "sem domínios de rastreamento"
assert d.get("NSPrivacyCollectedDataTypes", None) == [], "o app não coleta dados"
tipos = {t["NSPrivacyAccessedAPIType"] for t in d.get("NSPrivacyAccessedAPITypes", [])}
assert "NSPrivacyAccessedAPICategoryUserDefaults" in tipos, "declare o uso de UserDefaults"
PY
echo "ok: manifesto de privacidade"
