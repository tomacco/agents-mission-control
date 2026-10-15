#!/bin/zsh
# Proof that the grant step leaves System Settings in front of Finder. It opens real windows, so it runs
# against a throwaway test copy and only when hands off is off.
root=${0:A:h:h}; cd $root
[[ -e ~/.agent-board/hands-off ]] && { print "SKIP: hands off is on (Agent Board)"; exit 0 }
S=$(mktemp -d -t amc-grant); export AMC_CHANNEL=test CLAUDE_CONFIG_DIR=$S/claude AMC_NO_GRANT=1 AMC_PLAIN=1
trap './uninstall.sh --yes >/dev/null; rm -rf $S' EXIT
./install.sh >/dev/null 2>&1 || { print "FAIL install"; exit 1 }
source ./channel.sh
for i in {1..40}; do print '{"op":"status"}' | bin/amc-call | grep -q leases && break; sleep 0.25; done
print '{"op":"grant"}' | bin/amc-call >/dev/null
sleep 3
front=$(lsappinfo info -only name "$(lsappinfo front)" | head -1)
[[ $front == *'"System Settings"'* ]] && { print "PASS System Settings is in front"; exit 0 } || { print "FAIL front app is $front"; exit 1 }
