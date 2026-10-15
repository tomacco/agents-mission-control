#!/bin/zsh
# Remove Agents Mission Control from this Mac: the app, both LaunchAgents, the Claude Code hook, its
# folder (~/.amc, with the trace log and run output) and every macOS permission granted to it.
#   ./uninstall.sh              asks before deleting the folder
#   ./uninstall.sh --yes        no questions (scripts, tests)
#   AMC_CHANNEL=test ./uninstall.sh --yes   removes the test copy only
cd "${0:A:h}"; ROOT=$PWD
source ./channel.sh
LA=~/Library/LaunchAgents
for name in amcd app; do
  launchctl bootout gui/$(id -u) $LA/$ID.$name.plist 2>/dev/null
  rm -f $LA/$ID.$name.plist
done
osascript -e "quit app id \"$ID\"" 2>/dev/null
pkill -f "$APPFILE/Contents/MacOS/" 2>/dev/null
rm -rf ~/Applications/$APPFILE
tccutil reset All $ID >/dev/null 2>&1

if [[ -f $CLAUDE_DIR/settings.json ]]; then
  python3 - "$ROOT/hooks/hands-off-guard.sh" "$CLAUDE_DIR/settings.json" <<'PY'
import json, sys
hook, p = sys.argv[1], sys.argv[2]
s = json.load(open(p)); n = 0
for e in s.get("hooks", {}).get("PreToolUse", []):
    keep = [h for h in e.get("hooks", []) if not h.get("command", "").endswith(hook)]
    n += len(e.get("hooks", [])) - len(keep); e["hooks"] = keep
if "hooks" in s:
    s["hooks"]["PreToolUse"] = [e for e in s["hooks"].get("PreToolUse", []) if e.get("hooks")]
json.dump(s, open(p, "w"), indent=2); open(p, "a").write("\n")
print(f"hook entries removed: {n}")
PY
fi

if [[ -d $AMC_HOME ]]; then
  if [[ $1 == --yes ]] || { read -q "?Delete $AMC_HOME (trace log and run output)? [y/N] " && print; }; then
    rm -rf $AMC_HOME
  else
    print "\nKept $AMC_HOME"
  fi
fi
print "$APPNAME removed. The Claude Code plugin is separate: /plugin uninstall amc"
