#!/bin/zsh
# Try the whole installation the way a new user gets it, then remove every trace of it.
# Your real install is untouched: this is the "test" channel (its own app identity, folder, socket,
# LaunchAgents and Full Disk Access grant), and Claude Code runs with a throwaway config folder.
#   zsh tests/try-install.sh                   clone the public repo (what users get)
#   AMC_SOURCE=. zsh tests/try-install.sh      use this checkout's last commit
SRC=${AMC_SOURCE:-https://github.com/tomacco/agents-mission-control.git}
[[ $SRC == . ]] && SRC=${0:A:h:h}
T=$(mktemp -d -t amc-try)
export AMC_CHANNEL=test CLAUDE_CONFIG_DIR=$T/claude

cleanup() {
  trap - EXIT INT TERM
  print "\n== Removing the test copy"
  [[ -x $T/amc/uninstall.sh ]] && $T/amc/uninstall.sh --yes
  rm -rf $T
  print "\n== Checking nothing is left"
  local left=0
  launchctl list | grep -q 'co.tomac.amc.test' && { print "LEFT LaunchAgent co.tomac.amc.test.*"; left=1 }
  ls ~/Library/LaunchAgents/co.tomac.amc.test.* >/dev/null 2>&1 && { print "LEFT LaunchAgent plists"; left=1 }
  [[ -e ~/Applications/AgentsMissionControl-test.app ]] && { print "LEFT ~/Applications/AgentsMissionControl-test.app"; left=1 }
  [[ -e ~/.amc-test ]] && { print "LEFT ~/.amc-test"; left=1 }
  pgrep -f 'AgentsMissionControl-test.app/Contents/MacOS/' >/dev/null && { print "LEFT running test app"; left=1 }
  [[ -n $(tccutil list -b co.tomac.amc.test 2>/dev/null) ]] && { print "LEFT macOS permissions for co.tomac.amc.test"; left=1 }
  [[ -e $T ]] && { print "LEFT $T"; left=1 }
  (( left )) && print "Cleanup incomplete." || print "Clean: nothing of the test copy remains."
}
trap cleanup EXIT INT TERM

print "== Getting the code from $SRC"
git clone -q --depth 1 "file://${SRC#file://}" $T/amc 2>/dev/null || git clone -q --depth 1 $SRC $T/amc || exit 1
cd $T/amc
print "== Installing (test channel)"
./install.sh || exit 1
source ./channel.sh

MARKET=tomacco/agents-mission-control
[[ $SRC == /* ]] && MARKET=$T/amc
cat <<MSG

== Claude Code opens now with a fresh config folder (you may have to log in once). Inside it:
   1. /plugin install amc --marketplace $MARKET      (answer y, then pick the user scope)
   2. Ask: Show me the 5 most recently modified files under ~/Library/Mail
   3. /exit when done. Everything installed here is then removed.
MSG
print -n "/plugin install amc --marketplace $MARKET" | pbcopy && print "   (step 1 is on your clipboard)\n"
AMC_SOCKET=$AMC_SOCKET ~/.local/bin/claude
