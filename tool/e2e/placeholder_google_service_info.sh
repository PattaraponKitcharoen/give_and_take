#!/bin/sh
# Writes a placeholder ios/Runner/GoogleService-Info.plist pointing at the
# demo-give-and-take emulator project, for integration tests (CI writes it
# on a clean checkout). iOS sets up Firebase from this file before Dart
# runs, so emulator builds need the demo project here, not the real one.
# The values only have to look valid (Firebase checks the API key's format
# at launch); the emulators never check them.
#
# Locally, keep your real file safe first:
#   cp ios/Runner/GoogleService-Info.plist /somewhere/safe/
#   tool/e2e/placeholder_google_service_info.sh
#   ... run the tests ...
#   cp /somewhere/safe/GoogleService-Info.plist ios/Runner/
set -e
cd "$(dirname "$0")/../.."
cat > ios/Runner/GoogleService-Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key><string>AIzaDemoPlaceholderForEmulatorOnly00000</string>
  <key>GCM_SENDER_ID</key><string>000000000000</string>
  <key>BUNDLE_ID</key><string>com.pattarapon.giveAndTake</string>
  <key>PROJECT_ID</key><string>demo-give-and-take</string>
  <key>STORAGE_BUCKET</key><string>demo-give-and-take.appspot.com</string>
  <key>GOOGLE_APP_ID</key><string>1:000000000000:ios:0000000000000000</string>
</dict>
</plist>
PLIST
echo "Wrote placeholder GoogleService-Info.plist (demo-give-and-take)"
