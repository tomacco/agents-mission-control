#!/bin/zsh
# Install Agents Mission Control on this Mac: build the app, run the enforcer and the app at login,
# and register the Claude Code hook. Idempotent.
set -e
cd "${0:A:h}"; ROOT=$PWD
source ./channel.sh
./build.sh
mkdir -p ~/Applications && rm -rf ~/Applications/$APPFILE && cp -R build/$APPFILE ~/Applications/
LA=~/Library/LaunchAgents
for name in amcd app; do
  plist=$LA/$ID.$name.plist
  sed "s|@ROOT@|$ROOT|g; s|@HOME@|$HOME|g; s|@ID@|$ID|g; s|@SUF@|$SUF|g; s|@AMCHOME@|$AMC_HOME|g; s|@APPFILE@|$APPFILE|g" \
    launchd/co.tomac.amc.$name.plist > $plist
  launchctl bootout gui/$(id -u) $plist 2>/dev/null || true
  launchctl bootstrap gui/$(id -u) $plist
done
hook=$ROOT/hooks/hands-off-guard.sh; [[ -n $CH ]] && hook="AMC_FLAG=$AMC_FLAG $hook"
mkdir -p "$CLAUDE_DIR"; [[ -f $CLAUDE_DIR/settings.json ]] || print "{}" > "$CLAUDE_DIR/settings.json"
python3 - "$hook" "$CLAUDE_DIR/settings.json" <<'PY'
import json, os, sys
hook, p = sys.argv[1], sys.argv[2]
s = json.load(open(p))
pre = s.setdefault("hooks", {}).setdefault("PreToolUse", [])
if not any(h.get("command") == hook for e in pre for h in e.get("hooks", [])):
    pre.append({"matcher": "Bash", "hooks": [{"type": "command", "command": hook, "timeout": 5,
                "statusMessage": "AMC: hands-off guard"}]})
    json.dump(s, open(p, "w"), indent=2); open(p, "a").write("\n")
    print("hook registered")
PY
echo "$APPNAME installed. Proof: tests/test-hands-off.sh"

# Full Disk Access: macOS has no prompt for it, so open the one toggle, show the app ready to drag in, and wait.
call=$ROOT/bin/amc-call
for i in {1..20}; do print '{"op":"status"}' | $call | grep -q '"leases"' && break; sleep 0.5; done
if [[ -z $AMC_NO_GRANT ]] && print '{"op":"status"}' | $call | grep -q '"fda":false'; then
  print '{"op":"grant"}' | $call >/dev/null
  [[ -f $AMC_FLAG ]] || afplay /System/Library/Sounds/Glass.aiff &!
  print "\nPrivileged sessions need Full Disk Access. System Settings and Finder are open:"
  print "drag $APPFILE into the Full Disk Access list (or press + and pick it), then switch it on."
  if [[ -t 1 ]]; then
    print "Waiting for it... (Ctrl-C to skip; the menu bar panel offers it again later)"
    until print '{"op":"status"}' | $call 2>/dev/null | grep -q '"fda":true'; do sleep 2; done
    print "Full Disk Access granted: privileged sessions are ready."
  fi
fi
