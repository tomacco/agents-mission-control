#!/bin/zsh
# Prove that scripts/verify-app.sh, the gate install.sh puts in front of every download, passes the author's
# notarized release and refuses everything else: no bundle, unsigned, ad hoc, the release re-signed by someone
# else, the release changed after signing, and (on a Mac with a Developer ID) signed but not notarized.
#   zsh tests/test-verify.sh [release.app]    default: the latest GitHub release (skipped only if none exists)
cd "${0:A:h:h}"
V=$PWD/scripts/verify-app.sh T=$(mktemp -d -t amc-verify) fails=0
trap 'rm -rf $T' EXIT
expect() {  # expect pass|refuse <label> <app>
  local out; out=$($V $3 2>&1); local code=$?
  if [[ $1 == pass && $code == 0 || $1 == refuse && $code != 0 ]]; then print "ok    $2: $out"
  else print "FAIL  $2 (wanted $1, exit $code): $out"; fails=1; fi
}
bundle() {  # a minimal app bundle with the release's bundle id
  mkdir -p $1/Contents/MacOS
  print '#!/bin/sh\nexit 0' > $1/Contents/MacOS/AgentsMissionControl; chmod +x $1/Contents/MacOS/AgentsMissionControl
  plutil -create xml1 $1/Contents/Info.plist
  plutil -insert CFBundleIdentifier -string co.tomac.amc $1/Contents/Info.plist
  plutil -insert CFBundleExecutable -string AgentsMissionControl $1/Contents/Info.plist
}

GOOD=${1:-}
source tests/release-zip.sh
if [[ -z $GOOD ]] && fetch_release $T/release.zip; then
  unzip_release $T/release.zip $T/release; GOOD=$T/release/AgentsMissionControl.app
fi

mkdir -p $T/empty;                       expect refuse "not a bundle" $T/empty
bundle $T/unsigned.app;                  expect refuse "unsigned" $T/unsigned.app
bundle $T/adhoc.app; codesign -s - $T/adhoc.app 2>/dev/null; expect refuse "ad hoc" $T/adhoc.app
SIGNER=$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)
if [[ -n $SIGNER ]]; then
  bundle $T/unnotarized.app
  codesign -s "$SIGNER" --options runtime --timestamp $T/unnotarized.app 2>/dev/null
  expect refuse "Developer ID, not notarized" $T/unnotarized.app
fi
if [[ -n $GOOD ]]; then
  expect pass "the release" $GOOD
  ditto $GOOD $T/resigned.app; codesign -f -s - $T/resigned.app 2>/dev/null
  expect refuse "release re-signed ad hoc" $T/resigned.app
  ditto $GOOD $T/tampered.app; print '# changed' >> $T/tampered.app/Contents/Info.plist
  expect refuse "release changed after signing" $T/tampered.app
else
  print "skip  the release cases: GitHub has no signed release yet"
fi
(( fails )) && print "test-verify: FAILED" || print "test-verify: all passed"
exit $fails
