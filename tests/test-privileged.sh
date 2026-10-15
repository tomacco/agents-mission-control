#!/bin/zsh
# Proof for privileged sessions, against the running app. Run it from a Claude Code session that does not have
# the amc mod loaded (the mod takes this session's key first): `! zsh tests/test-privileged.sh`.
root=${0:A:h:h}; call=$root/bin/amc-call; pass=0; fail=0
ok()  { print "PASS $1"; pass=$((pass+1)) }
bad() { print "FAIL $1"; fail=$((fail+1)) }
j()   { python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$1',''))" }
q()   { print -r -- "$1" | $call }

q '{"op":"status"}' | grep -q leases && ok "status answers" || { bad "app not answering on ~/.amc/amc.sock"; exit 1 }
q '{"op":"status"}' | grep -q '"fda":true' && ok "app reports its Full Disk Access" || bad "app reports no Full Disk Access: grant it, then rerun"
q '{"op":"grant","dry":1}' | grep -q '"fda"' && ok "grant op answers" || bad "grant op"

# A caller outside Claude Code (started by launchd) is refused.
out=$(mktemp); launchctl submit -l co.tomac.amc.test -- /bin/zsh -c "print '{\"op\":\"register\"}' | $call > $out"
sleep 2; launchctl remove co.tomac.amc.test 2>/dev/null
grep -q "not a Claude Code session" $out && ok "non-Claude caller refused" || bad "non-Claude caller: $(cat $out)"

key=$(q '{"op":"register"}' | j key)
[[ -n $key ]] || { print "SKIP rest: this session is already registered (the mod holds its key)"; print "\n$pass passed, $fail failed"; exit $fail }
ok "register gives a key"
[[ -z $(q '{"op":"register"}' | j key) ]] && ok "second register refused" || bad "second register gave a key"

q "{\"op\":\"run\",\"key\":\"$key\",\"command\":\"true\",\"reason\":\"t\"}" | grep -q "no open lease" && ok "run without lease refused" || bad "run without lease"
q '{"op":"open","key":"nope","agent":"t","subtitle":"t","reason":"t","paths":[]}' | grep -q "bad or missing" && ok "bad key refused" || bad "bad key"

q "{\"op\":\"open\",\"key\":\"$key\",\"agent\":\"test\",\"subtitle\":\"privileged proof\",\"reason\":\"test\",\"paths\":[\"~/Library/Mail\"],\"scope\":\"once\"}" | grep -q '"ok"' && ok "open once" || bad "open once"
r=$(q "{\"op\":\"run\",\"key\":\"$key\",\"run_id\":\"test-mail\",\"command\":\"ls ~/Library/Mail >/dev/null && echo readable\",\"reason\":\"test\"}")
[[ $(print -r -- $r | j exit) == 0 ]] && ok "app child reads ~/Library/Mail" || bad "privileged read: $r $(cat ~/.amc/runs/test-mail.log 2>/dev/null)"
q "{\"op\":\"run\",\"key\":\"$key\",\"command\":\"true\",\"reason\":\"t\"}" | grep -q "no open lease" && ok "once lease consumed" || bad "once lease still open"
ls ~/Library/Mail >/dev/null 2>&1 && bad "Terminal can read ~/Library/Mail (grant leaked)" || ok "Terminal still cannot read ~/Library/Mail"

q "{\"op\":\"open\",\"key\":\"$key\",\"agent\":\"test\",\"subtitle\":\"privileged proof\",\"reason\":\"test\",\"paths\":[],\"scope\":\"session\"}" >/dev/null
r1=$(q "{\"op\":\"run\",\"key\":\"$key\",\"command\":\"exit 3\",\"reason\":\"t\"}" | j exit); r2=$(q "{\"op\":\"run\",\"key\":\"$key\",\"command\":\"true\",\"reason\":\"t\"}" | j exit)
[[ $r1 == 3 && $r2 == 0 ]] && ok "session lease covers several runs, exit codes kept" || bad "session runs: $r1 $r2"
q "{\"op\":\"end\",\"key\":\"$key\"}" >/dev/null
q "{\"op\":\"run\",\"key\":\"$key\",\"command\":\"true\",\"reason\":\"t\"}" | grep -q "no open lease" && ok "end closes the lease" || bad "end"

python3 - ~/.amc/trace.jsonl <<'PY' && ok "trace hash chain intact" || bad "trace hash chain broken"
import hashlib, json, sys
prev = None
for line in open(sys.argv[1], 'rb').read().splitlines():
    if prev is not None and json.loads(line)['prev'] != hashlib.sha256(prev).hexdigest(): sys.exit(1)
    prev = line
PY
print "\n$pass passed, $fail failed"; exit $fail
