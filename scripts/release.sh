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
# A tag on this commit is a retry of a release that stopped half way; on another commit it is a used version.
if git rev-parse -q --verify "refs/tags/v$V" >/dev/null; then
  [[ $(git rev-list -n 1 "v$V") == $(git rev-parse HEAD) ]] || fail "tag v$V is on another commit; bump VERSION"
fi
[[ $(gh release view "v$V" --json isDraft -q .isDraft 2>/dev/null || true) == false ]] && fail "v$V is published; bump VERSION"
source ~/.appstoreconnect/config
NOTARY=(--key "${ASC_KEY_PATH/#\~/$HOME}" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")

./build.sh
APP=build/AgentsMissionControl.app OUT=build/release
codesign -dv $APP 2>&1 | grep -q 'TeamIdentifier=Y4UQ4S5ANQ' || fail "not signed with the Developer ID (Y4UQ4S5ANQ)"
zsh tests/check-personal.sh --artifact $APP || fail "the app holds a personal path or the login name"
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
git rev-parse -q --verify "refs/tags/v$V" >/dev/null || git tag -a "v$V" -m "Agents Mission Control $V"
git push origin "v$V"
# Upload to a draft (installers only see published releases), check the upload, then publish.
if state=$(gh release view "v$V" --json isDraft -q .isDraft 2>$OUT/gh.err); then
  [[ $state == true ]] || fail "v$V is published; bump VERSION"
  gh release delete "v$V" --yes                                # a draft left by a stopped run
else
  grep -q 'release not found' $OUT/gh.err || fail "cannot read release v$V: $(<$OUT/gh.err)"
fi
gh release create "v$V" --draft $ZIP $OUT/AgentsMissionControl.zip.sha256 --title "Agents Mission Control $V" --notes-file $OUT/notes.md
gh release download "v$V" -p AgentsMissionControl.zip -D $OUT/uploaded --clobber
cmp -s $ZIP $OUT/uploaded/AgentsMissionControl.zip || fail "the uploaded zip differs from the local one; the draft is kept"
gh release edit "v$V" --draft=false --latest
print "Released v$V"
