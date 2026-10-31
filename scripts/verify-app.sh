#!/bin/zsh
# Check that an app bundle is the release Ivan Gonzalez signed and Apple notarized. Prints the reason and exits 1
# when it is not. install.sh runs it on every downloaded release; tests/test-verify.sh proves it refuses the rest.
#   scripts/verify-app.sh <AgentsMissionControl.app>
APP=${1:?usage: verify-app.sh <app>}
TEAM=Y4UQ4S5ANQ
# The designated requirement of a real release: Apple-issued Developer ID chain, this bundle id, this team.
REQ="anchor apple generic and identifier \"co.tomac.amc\" and certificate leaf[subject.OU] = \"$TEAM\""
fail() { print -u2 "Refused $APP: $1"; exit 1 }

[[ -d $APP/Contents/MacOS ]] || fail "not an app bundle"
codesign --verify --deep --strict "$APP" 2>/dev/null || fail "the signature is broken or the bundle was changed after signing"
codesign --verify -R="$REQ" "$APP" 2>/dev/null || fail "not signed by team $TEAM as co.tomac.amc"
codesign -dv "$APP" 2>&1 | grep -q 'flags=.*runtime' || fail "hardened runtime is off, so it cannot be notarized"
# Gatekeeper's own verdict, the same check macOS makes when a downloaded app is opened.
spctl -a -t exec -vv "$APP" 2>&1 | grep -q 'source=Notarized Developer ID' || fail "Apple has not notarized it"
print "Verified: signed by team $TEAM, notarized by Apple"
