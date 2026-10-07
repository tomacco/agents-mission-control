#!/bin/zsh
# Install Helm on this Mac: build the app, run the enforcer and the app at login,
# and register the Claude Code hook. Idempotent.
set -e
cd "${0:A:h}"; ROOT=$PWD
./build.sh
mkdir -p ~/Applications && rm -rf ~/Applications/Helm.app && cp -R build/Helm.app ~/Applications/
LA=~/Library/LaunchAgents
for name in helmd app; do
  plist=$LA/co.tomac.helm.$name.plist
  sed "s|@ROOT@|$ROOT|g; s|@HOME@|$HOME|g" launchd/co.tomac.helm.$name.plist > $plist
  launchctl bootout gui/$(id -u) $plist 2>/dev/null || true
  launchctl bootstrap gui/$(id -u) $plist
done
python3 - "$ROOT/hooks/hands-off-guard.sh" <<'PY'
import json, os, sys
p = os.path.expanduser("~/.claude/settings.json"); hook = sys.argv[1]
s = json.load(open(p))
pre = s.setdefault("hooks", {}).setdefault("PreToolUse", [])
if not any(h.get("command") == hook for e in pre for h in e.get("hooks", [])):
    pre.append({"matcher": "Bash", "hooks": [{"type": "command", "command": hook, "timeout": 5,
                "statusMessage": "Helm: hands-off guard"}]})
    json.dump(s, open(p, "w"), indent=2); open(p, "a").write("\n")
    print("hook registered")
PY
echo "Helm installed. Proof: tests/test-hands-off.sh"
