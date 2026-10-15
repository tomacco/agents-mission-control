#!/bin/zsh
# Proof for privileged sessions, against the running app.
#   zsh tests/test-privileged.sh              checks that need no person: refusals, status, trace
#   zsh tests/test-privileged.sh --touch-id   also approves with Touch ID (twice) and runs commands
# Run it from a Claude Code session (`! zsh tests/test-privileged.sh`): callers must descend from Claude Code.
root=${0:A:h:h}; call=$root/bin/amc-call; pass=0; fail=0
ok()  { print "PASS $1"; pass=$((pass+1)) }
bad() { print "FAIL $1"; fail=$((fail+1)) }
j()   { python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$1',''))" }
q()   { print -r -- "$1" | $call }

q '{"op":"status"}' | grep -q leases && ok "status answers" || { bad "app not answering on ${AMC_SOCKET:-~/.amc/amc.sock}"; exit 1 }
q '{"op":"status"}' | grep -q '"fda":true' && ok "app reports its Full Disk Access" || bad "app reports no Full Disk Access: grant it, then rerun"
q '{"op":"grant","dry":1}' | grep -q '"fda"' && ok "grant op answers" || bad "grant op"

# A caller outside Claude Code (started by launchd) is refused before anyone is asked.
out=$(mktemp); launchctl submit -l co.tomac.amc.test-caller -- /bin/zsh -c "print '{\"op\":\"open\",\"agent\":\"x\",\"reason\":\"x\"}' | $call > $out"
sleep 2; launchctl remove co.tomac.amc.test-caller 2>/dev/null
grep -q "not a Claude Code session" $out && ok "non-Claude caller refused" || bad "non-Claude caller: $(cat $out)"

q '{"op":"run","command":"true","reason":"t"}' | grep -q "no open lease" && ok "run without approval refused" || bad "run without approval"
q '{"op":"register"}' | grep -q "unknown op" && ok "no session keys any more (register is gone)" || bad "register still answers"

if [[ $1 == --touch-id ]]; then
  print "\n>> Touch ID 1 of 2: approve 'one command'"
  q '{"op":"open","agent":"test","subtitle":"privileged proof","reason":"test run","paths":["~/Library/Mail"],"scope":"once"}' | grep -q '"ok"' \
    && ok "open once after Touch ID" || bad "open once"
  r=$(q '{"op":"run","run_id":"test-mail","command":"ls ~/Library/Mail >/dev/null && echo readable","reason":"test"}')
  [[ $(print -r -- $r | j exit) == 0 ]] && ok "app child reads ~/Library/Mail" || bad "privileged read: $r"
  q '{"op":"run","command":"true","reason":"t"}' | grep -q "no open lease" && ok "once lease consumed" || bad "once lease still open"
  ls ~/Library/Mail >/dev/null 2>&1 && bad "Terminal can read ~/Library/Mail (grant leaked)" || ok "Terminal still cannot read ~/Library/Mail"

  print "\n>> Touch ID 2 of 2: approve 'this session'"
  q '{"op":"open","agent":"test","subtitle":"privileged proof","reason":"test session","paths":[],"scope":"session"}' >/dev/null
  r1=$(q '{"op":"run","command":"exit 3","reason":"t"}' | j exit); r2=$(q '{"op":"run","command":"true","reason":"t"}' | j exit)
  [[ $r1 == 3 && $r2 == 0 ]] && ok "session lease covers several runs, exit codes kept" || bad "session runs: $r1 $r2"
  r3=$(q '{"op":"run","command":"false | cat","reason":"t"}' | j exit)
  [[ $r3 != 0 ]] && ok "a failure inside a pipe shows in the exit code (pipefail)" || bad "pipefail: exit $r3"
  q '{"op":"end"}' >/dev/null
  q '{"op":"run","command":"true","reason":"t"}' | grep -q "no open lease" && ok "end closes the lease" || bad "end"
else
  print "SKIP approval and runs (need Touch ID): rerun with --touch-id"
fi

trace=${AMC_SOCKET:-$HOME/.amc/amc.sock}; trace=${trace%amc.sock}trace.jsonl
python3 - $trace <<'PY' && ok "trace hash chain intact" || bad "trace hash chain broken"
import hashlib, json, sys
prev = None
for line in open(sys.argv[1], 'rb').read().splitlines():
    if prev is not None and json.loads(line)['prev'] != hashlib.sha256(prev).hexdigest(): sys.exit(1)
    prev = line
PY
print "\n$pass passed, $fail failed"; exit $fail
