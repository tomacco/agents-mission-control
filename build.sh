#!/bin/zsh
# Build AgentsMissionControl.app (menu bar only) from the SwiftPM target. Signed with the Developer ID when the
# keychain has it, so the Full Disk Access grant survives rebuilds; ad-hoc otherwise (the grant then breaks every build).
set -e
cd "${0:A:h}"
source ./channel.sh
swift build -c release
APP="build/$APPFILE"
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS"
cp .build/release/AgentsMissionControl "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$APPNAME</string>
<key>CFBundleIdentifier</key><string>$ID</string>
<key>CFBundleExecutable</key><string>AgentsMissionControl</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>AMCRoot</key><string>$PWD</string>
<key>AMCHome</key><string>$AMC_HOME</string>
</dict></plist>
PLIST
SIGNER=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)
codesign --force --sign "${SIGNER:--}" "$APP"
echo "$APP"
