#!/bin/zsh
# Publish the release named in VERSION: build, sign with Developer ID, notarize, staple, verify, then tag and upload
# AgentsMissionControl.zip to GitHub. Runs on the author's Mac (the certificate lives in its keychain; see
# backlog decision-5). The App Store Connect API key comes from ~/.appstoreconnect/config (ASC_KEY_ID,
# ASC_ISSUER_ID, ASC_KEY_PATH), so notarizing needs no password.
#   scripts/release.sh            everything
#   scripts/release.sh --dry-run  build, notarize and verify; no tag, no upload
set -euo pipefail
cd "${0:A:h:h}"
fail() { print -u2 "release: $1"; exit 1 }
V=$(<VERSION) DRY=${1:-}
[[ -z ${AMC_CHANNEL:-} ]] || fail "unset AMC_CHANNEL: a release is the real app"
if [[ $DRY != --dry-run ]]; then
  [[ $(git branch --show-current) == main ]] || fail "release from main"
  [[ -z $(git status --porcelain) ]] || fail "commit or remove local changes first"
fi
grep -q "^## $V " CHANGELOG.md || fail "CHANGELOG.md has no '## $V (date)' section"
git rev-parse -q --verify "refs/tags/v$V" >/dev/null && fail "tag v$V exists; bump VERSION"
source ~/.appstoreconnect/config
NOTARY=(--key "${ASC_KEY_PATH/#\~/$HOME}" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")

./build.sh
APP=build/AgentsMissionControl.app OUT=build/release
codesign -dv $APP 2>&1 | grep -q 'TeamIdentifier=Y4UQ4S5ANQ' || fail "not signed with the Developer ID (Y4UQ4S5ANQ)"
rm -rf $OUT && mkdir -p $OUT
# Notarize the app itself and staple its ticket, so it verifies offline once installed.
ditto -c -k --keepParent $APP $OUT/submit.zip
xcrun notarytool submit $OUT/submit.zip "${NOTARY[@]}" --wait | tee $OUT/notary.log
grep -q 'status: Accepted' $OUT/notary.log || fail "notarization was not accepted (see $OUT/notary.log)"
xcrun stapler staple $APP
xcrun stapler validate $APP
ZIP=$OUT/AgentsMissionControl.zip
ditto -c -k --keepParent $APP $ZIP
# Verify what users get: the zip, unpacked, through the same check install.sh runs.
mkdir $OUT/check && ditto -x -k $ZIP $OUT/check && ./scripts/verify-app.sh $OUT/check/AgentsMissionControl.app
shasum -a 256 $ZIP | tee $OUT/AgentsMissionControl.zip.sha256
[[ $DRY == --dry-run ]] && { print "Dry run: $ZIP is ready, nothing published."; exit 0 }

awk -v v="## $V " 'index($0, v) == 1 {on = 1; next} on && /^## / {exit} on' CHANGELOG.md > $OUT/notes.md
git tag -a "v$V" -m "Agents Mission Control $V"
git push origin "v$V"
gh release create "v$V" $ZIP $OUT/AgentsMissionControl.zip.sha256 --title "Agents Mission Control $V" --notes-file $OUT/notes.md
print "Released v$V"
