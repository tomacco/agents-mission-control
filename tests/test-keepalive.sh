#!/bin/zsh
# Proof that the app comes back after it quits (macOS quits it when Full Disk Access is switched on) and that a
# second copy started outside launchd steps aside. Runs against a throwaway test copy and removes it.
root=${0:A:h:h}; cd $root; pass=0; fail=0
ok()  { print "PASS $1"; pass=$((pass+1)) }
bad() { print "FAIL $1"; fail=$((fail+1)) }
S=$(mktemp -d -t amc-keepalive); export AMC_CHANNEL=test CLAUDE_CONFIG_DIR=$S/claude AMC_NO_GRANT=1 AMC_PLAIN=1
trap './uninstall.sh --yes >/dev/null; rm -rf $S' EXIT
./install.sh >/dev/null 2>&1 || { print "FAIL install"; exit 1 }
source ./channel.sh
up()   { print '{"op":"status"}' | bin/amc-call | grep -q leases }
pids() { pgrep -f "AgentsMissionControl-test.app/Contents/MacOS/" }
for i in {1..40}; do up && break; sleep 0.25; done
up && ok "app answers after install" || bad "app not answering after install"
first=$(pids | head -1)
[[ $(ps -o ppid= -p $first | tr -d ' ') == 1 ]] && ok "launchd runs the app itself" || bad "app parent is not launchd"

kill -TERM $first; sleep 1
for i in {1..40}; do up && [[ $(pids | head -1) != $first ]] && break; sleep 0.25; done
up && [[ $(pids | head -1) != $first ]] && ok "app restarted by launchd after it quit" || bad "app did not come back"

open -n -g -b co.tomac.amc.test; sleep 3
[[ $(pids | wc -l | tr -d ' ') == 1 ]] && ok "a second copy steps aside" || bad "$(pids | wc -l | tr -d ' ') copies running"
up && ok "socket still answers" || bad "socket lost"
print "\n$pass passed, $fail failed"; exit $fail
