#!/bin/zsh
# Install or update Agents Mission Control on this Mac: get the app and start it at login. Idempotent. It has no
# menu bar item: the installer and the Claude Code plugin are what the person sees.
set -e
cd "${0:A:h}"; ROOT=$PWD
[[ $1 == --from-source ]] && export AMC_FROM_SOURCE=1
# In a terminal, the animated installer (tools/installer.py) runs this script and draws its steps.
if [[ -t 1 && -z $AMC_UI && -z $AMC_PLAIN && -z $NO_COLOR ]]; then exec /usr/bin/python3 -I tools/installer.py; fi
step() { [[ -n $AMC_UI ]] && print "@@step $1 $2" || true }
source ./channel.sh
# By default: the latest release, signed by the author and notarized, verified before it is installed. Run again
# to update. A test channel or --from-source builds this checkout instead, signed by you or ad hoc.
if [[ -n $CH || -n $AMC_FROM_SOURCE ]]; then
  step build "Building the app from source"
  ./build.sh
  APP=build/$APPFILE
else
  step build "Downloading the signed release"
  URL=${AMC_RELEASE_URL:-https://github.com/tomacco/agents-mission-control/releases/latest/download/AgentsMissionControl.zip}
  DL=$(mktemp -d -t amc-release); trap 'rm -rf $DL' EXIT
  curl -fsSL --retry 2 -o $DL/app.zip "$URL"
  ditto -x -k $DL/app.zip $DL
  APP=$DL/$APPFILE
fi
step sign "Checking the signature"
if [[ -n $DL ]]; then ./scripts/verify-app.sh $APP || exit 1; fi
sig=$(codesign -dv $APP 2>&1)
step signer "$(print -r -- $sig | sed -n 's/^Authority=//p' | head -1)"
step team "$(print -r -- $sig | sed -n 's/^TeamIdentifier=//p' | head -1)"
version() { plutil -extract CFBundleShortVersionString raw $1/Contents/Info.plist 2>/dev/null || true }
old=$(version ~/Applications/$APPFILE) new=$(version $APP)
step app "Installing ${new:+$new }into ~/Applications"
mkdir -p ~/Applications && rm -rf ~/Applications/$APPFILE && cp -R $APP ~/Applications/
[[ -n $old && $old != $new ]] && print "Updated $old to $new"
step agents "Starting the app at login"
LA=~/Library/LaunchAgents
plist=$LA/$ID.app.plist
sed "s|@HOME@|$HOME|g; s|@ID@|$ID|g; s|@APPFILE@|$APPFILE|g" launchd/co.tomac.amc.app.plist > $plist
launchctl bootout gui/$(id -u) $plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) $plist
# From 0.1.0, when this app also held hands off: its enforcer and Claude Code hook moved to Agent Board.
launchctl bootout gui/$(id -u) $LA/$ID.amcd.plist 2>/dev/null || true; rm -f $LA/$ID.amcd.plist
[[ -f $CLAUDE_DIR/settings.json ]] && python3 - "$ROOT/hooks/hands-off-guard.sh" "$CLAUDE_DIR/settings.json" <<'PY2'
import json, sys
hook, p = sys.argv[1], sys.argv[2]
s = json.load(open(p)); pre = s.get("hooks", {}).get("PreToolUse", [])
for e in pre: e["hooks"] = [h for h in e.get("hooks", []) if not h.get("command", "").endswith(hook)]
if pre: s["hooks"]["PreToolUse"] = [e for e in pre if e.get("hooks")]
json.dump(s, open(p, "w"), indent=2); open(p, "a").write("\n")
PY2
echo "$APPNAME installed. Proof: tests/test-privileged.sh"

# Full Disk Access: macOS has no prompt for it, so open the one toggle, show the app ready to drag in, and wait.
step start "Waiting for the app to answer"
call=$ROOT/bin/amc-call
for i in {1..20}; do print '{"op":"status"}' | $call | grep -q '"leases"' && break; sleep 0.5; done
if [[ -z $AMC_NO_GRANT && -z $AMC_UI ]] && print '{"op":"status"}' | $call | grep -q '"fda":false'; then
  print '{"op":"grant"}' | $call >/dev/null
  [[ -f ~/.agent-board/hands-off ]] || afplay /System/Library/Sounds/Glass.aiff &!
  print "\nPrivileged sessions need Full Disk Access. System Settings and Finder are open:"
  print "drag $APPFILE into the Full Disk Access list (or press + and pick it), then switch it on."
  if [[ -t 1 ]]; then
    print "Waiting for it... (Ctrl-C to skip; Claude Code asks again when an agent needs it)"
    until print '{"op":"status"}' | $call 2>/dev/null | grep -q '"fda":true'; do sleep 2; done
    print "Full Disk Access granted: privileged sessions are ready."
  fi
fi
