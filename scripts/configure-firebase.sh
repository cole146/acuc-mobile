#!/usr/bin/env bash
# Puts the Firebase config files in place (from CI secrets or files you dropped in ./firebase/)
# and wires the iOS Google sign-in URL scheme (REVERSED_CLIENT_ID) into Info.plist.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${GOOGLE_SERVICES_JSON_B64:-}" ]; then
  echo "$GOOGLE_SERVICES_JSON_B64" | base64 --decode > android/app/google-services.json
elif [ -f firebase/google-services.json ]; then
  cp firebase/google-services.json android/app/google-services.json
fi

if [ -n "${GOOGLE_SERVICE_INFO_PLIST_B64:-}" ]; then
  echo "$GOOGLE_SERVICE_INFO_PLIST_B64" | base64 --decode > ios/App/App/GoogleService-Info.plist
elif [ -f firebase/GoogleService-Info.plist ]; then
  cp firebase/GoogleService-Info.plist ios/App/App/GoogleService-Info.plist
fi

python3 - <<'PY'
import plistlib, sys
src = 'ios/App/App/GoogleService-Info.plist'
info = 'ios/App/App/Info.plist'
try:
    rev = plistlib.load(open(src, 'rb')).get('REVERSED_CLIENT_ID', '')
except Exception:
    rev = ''
d = plistlib.load(open(info, 'rb'))
if rev and not rev.startswith('REPLACE_'):
    d['CFBundleURLTypes'] = [{'CFBundleURLName': 'google-sign-in', 'CFBundleURLSchemes': [rev]}]
    plistlib.dump(d, open(info, 'wb'))
    print('iOS Google sign-in URL scheme set.')
else:
    print('WARNING: GoogleService-Info.plist is still the placeholder - Google sign-in and push will not work on iOS.', file=sys.stderr)
PY

[ -f android/app/google-services.json ] || echo "WARNING: android/app/google-services.json missing - push and Google sign-in will not work on Android." >&2
