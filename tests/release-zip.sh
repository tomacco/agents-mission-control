# Sourced by tests/test-verify.sh and tests/test-install.sh.
# fetch_release <dest.zip>: 0 = downloaded, 1 = no signed release exists yet (the caller may skip). Any other
# failure (network, HTTP error, a cut-off transfer, a release without its zip) exits 1, so a release test never
# passes by skipping. On a release event (GITHUB_EVENT_NAME=release) the zip of that tag is required.
fetch_release() {
  local base=https://github.com/tomacco/agents-mission-control/releases code api auth=()
  local url=$base/latest/download/AgentsMissionControl.zip
  [[ $GITHUB_EVENT_NAME == release ]] && url=$base/download/$GITHUB_REF_NAME/AgentsMissionControl.zip
  [[ -n $GITHUB_TOKEN ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  # Without -f curl exits 0 on a 404 (so the code can be read) and nonzero on a transfer error.
  code=$(curl -sSL --retry 2 -o $1 -w '%{http_code}' $url) || { print -u2 "release download failed: $url"; exit 1 }
  [[ $code == 200 ]] && return 0
  if [[ $code == 404 && $GITHUB_EVENT_NAME != release ]]; then
    # Skipping is allowed only when GitHub says so: no release, or the latest predates signed downloads (0.3.0).
    api=$(curl -sS "${auth[@]}" https://api.github.com/repos/tomacco/agents-mission-control/releases/latest) \
      || { print -u2 "GitHub API unreachable"; exit 1 }
    print -r -- $api | python3 -c '
import json, sys
d = json.load(sys.stdin)
if d.get("message") == "Not Found": sys.exit(0)
assets = [a["name"] for a in d.get("assets", [])]
sys.exit(0 if d.get("tag_name") in ("v0.1.0", "v0.2.0") and "AgentsMissionControl.zip" not in assets else 1)' \
      && return 1
  fi
  print -u2 "release download failed: HTTP $code from $url"; exit 1
}

# unzip_release <zip> <dir>: unpack, or exit 1 (a broken zip must fail the test, not skip it).
unzip_release() { ditto -x -k $1 $2 && [[ -d $2/AgentsMissionControl.app ]] || { print -u2 "cannot unpack $1"; exit 1 } }
