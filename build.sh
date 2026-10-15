#!/bin/zsh
# Build AgentsMissionControl.app (menu bar only, ad-hoc signed) from the SwiftPM target.
set -e
cd "${0:A:h}"
swift build -c release
APP=build/AgentsMissionControl.app
rm -rf $APP && mkdir -p $APP/Contents/MacOS
cp .build/release/AgentsMissionControl $APP/Contents/MacOS/
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Agents Mission Control</string>
<key>CFBundleIdentifier</key><string>co.tomac.amc</string>
<key>CFBundleExecutable</key><string>AgentsMissionControl</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>AMCRoot</key><string>$PWD</string>
</dict></plist>
PLIST
codesign --force --sign - $APP
echo $APP
