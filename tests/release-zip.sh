# Sourced by tests/test-verify.sh and tests/test-install.sh.
# fetch_release <dest.zip>: 0 = downloaded, 1 = no signed release exists yet (the caller may skip). Any other
# failure (network, HTTP error, a release without its zip) exits 1, so a release test never passes by skipping.
# On a release event (GITHUB_EVENT_NAME=release) the zip of that tag is required.
fetch_release() {
  local base=https://github.com/tomacco/agents-mission-control/releases code api
  local url=$base/latest/download/AgentsMissionControl.zip
  [[ $GITHUB_EVENT_NAME == release ]] && url=$base/download/$GITHUB_REF_NAME/AgentsMissionControl.zip
  code=$(curl -sSL --retry 2 -o $1 -w '%{http_code}' $url)
  [[ $code == 200 ]] && return 0
  if [[ $code == 404 && $GITHUB_EVENT_NAME != release ]]; then
    # Skipping is allowed only when GitHub says so: no release, or the latest predates signed downloads (0.3.0).
    api=$(curl -sS ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
      https://api.github.com/repos/tomacco/agents-mission-control/releases/latest)
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
