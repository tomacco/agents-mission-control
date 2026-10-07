#!/bin/zsh
# Proof that hands-off holds, and that turning it off gives control back.
# Uses a private flag/log so it never touches the live switch.
set -u
here=${0:A:h}; root=${here:h}
T=$(mktemp -d); export HELM_FLAG=$T/hands-off HELM_LOG=$T/helmd.log
pass=0 fail=0
ok()  { print "PASS $1"; (( ++pass )); }
bad() { print "FAIL $1"; (( ++fail )); }
hook() { print -r -- "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(print -r -- "$1" | /usr/bin/python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().rstrip("\n")))')}}" | $root/hooks/hands-off-guard.sh 2>/dev/null; echo $?; }

# A stand-in "uidriver" (a renamed sleep) so the test never moves the real mouse.
cp /bin/sleep $T/uidriver && /usr/bin/codesign -f -s - $T/uidriver 2>/dev/null
$root/bin/helmd & D=$!
trap 'kill $D 2>/dev/null; rm -rf $T' EXIT

# 1. Off: blocked names survive, the hook allows everything.
$T/uidriver 30 & U=$!; sleep 1
kill -0 $U 2>/dev/null && ok "off: uidriver survives" || bad "off: uidriver was killed"
[[ $(hook 'say hello') == 0 ]] && ok "off: hook allows say" || bad "off: hook blocked say"

# 2. On: running drivers die within a second, new speech dies before it is heard.
$root/bin/helmctl on test >/dev/null; sleep 0.6
kill -0 $U 2>/dev/null && bad "on: uidriver still alive" || ok "on: running uidriver killed"
/usr/bin/say -o $T/x.aiff "$(printf 'long sentence %.0s' {1..400})" & S=$!; sleep 0.8
kill -0 $S 2>/dev/null && bad "on: say still alive" || ok "on: new say killed"
grep -q 'killed' $HELM_LOG && ok "on: kills logged" || bad "on: no log"

# 3. On: the hook refuses voice, sound and input commands, and allows ordinary work.
for c in 'say -v Daniel "hi"' 'afplay /System/Library/Sounds/Glass.aiff &' './scripts/ui-check.sh' 'build/uidriver click 10 10' 'osascript -e "tell app \"System Events\" to keystroke \"a\""' 'cd x && say done'; do
  [[ $(hook $c) == 2 ]] && ok "on: hook blocks: $c" || bad "on: hook allowed: $c"
done
for c in 'git status' 'grep -r saying .' 'xcodebuild -scheme GlassCam build' 'cat essay.md' 'swift build'; do
  [[ $(hook $c) == 0 ]] && ok "on: hook allows: $c" || bad "on: hook blocked: $c"
done

# 4. Off again: control comes back.
$root/bin/helmctl off >/dev/null
$T/uidriver 30 & U=$!; sleep 1
kill -0 $U 2>/dev/null && ok "off again: uidriver survives" || bad "off again: uidriver killed"
kill $U 2>/dev/null
[[ $(hook 'say hello') == 0 ]] && ok "off again: hook allows say" || bad "off again: hook blocks say"

print "\n$pass passed, $fail failed"; (( fail == 0 ))
