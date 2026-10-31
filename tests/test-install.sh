#!/bin/zsh
# The install, update and removal a new user gets, end to end, on a clean macOS CI runner. It installs the REAL app
# (bundle id co.tomac.amc), so it refuses to run outside CI; on your own Mac use tests/try-install.sh.
#   zsh tests/test-install.sh [release.zip]   default: the latest GitHub release (release cases skipped if none)
#   AMC_TEST_SOURCE=1 zsh tests/test-install.sh   also the --from-source path on the test channel (builds the app)
[[ $CI == true ]] || { print "test-install: CI only, it installs the real app. On a Mac: zsh tests/try-install.sh"; exit 2 }
cd "${0:A:h:h}"; ROOT=$PWD
T=$(mktemp -d -t amc-install) fails=0
export AMC_PLAIN=1 AMC_NO_GRANT=1
check() { if eval "$2"; then print "ok    $1"; else print "FAIL  $1"; fails=1; fi }
answers() {  # answers <socket> <version>: the RUNNING app replies with that version
  for i in {1..30}; do
    AMC_SOCKET=$1 bin/amc-call <<< '{"op":"status"}' | grep -q "\"version\":\"$2\"" && return 0; sleep 1
  done; return 1
}
gone() { [[ ! -e ~/Applications/$1.app && ! -e ~/Library/LaunchAgents/$2.app.plist && ! -e $3 ]] && ! pgrep -qf "$1.app/Contents/MacOS/" }

print "== A download that is not the author's notarized release is refused, and nothing is installed"
mkdir -p $T/fake/AgentsMissionControl.app/Contents/MacOS
cp /usr/bin/true $T/fake/AgentsMissionControl.app/Contents/MacOS/AgentsMissionControl
codesign -f -s - $T/fake/AgentsMissionControl.app 2>/dev/null
ditto -c -k --keepParent $T/fake/AgentsMissionControl.app $T/fake.zip
check "ad hoc zip refused" "! AMC_RELEASE_URL=file://$T/fake.zip ./install.sh"
check "nothing installed after the refusal" "gone AgentsMissionControl co.tomac.amc ~/.amc"

ZIP=${1:-}
if [[ -z $ZIP ]] && curl -fsSL -o $T/release.zip \
    https://github.com/tomacco/agents-mission-control/releases/latest/download/AgentsMissionControl.zip; then
  ZIP=$T/release.zip
fi
if [[ -n $ZIP ]]; then
  ditto -x -k $ZIP $T/rel; V=$(plutil -extract CFBundleShortVersionString raw $T/rel/AgentsMissionControl.app/Contents/Info.plist)
  print "== Install release $V"
  check "install exits 0" "AMC_RELEASE_URL=file://${ZIP:A} ./install.sh"
  check "installed app passes the verifier" "scripts/verify-app.sh ~/Applications/AgentsMissionControl.app"
  check "the running app answers as $V" "answers ~/.amc/amc.sock $V"
  check "Info.plist names no home folder" "! plutil -p ~/Applications/AgentsMissionControl.app/Contents/Info.plist | grep -q /Users/"
  print "== Update: run the installer again"
  pid=$(pgrep -f 'AgentsMissionControl.app/Contents/MacOS/' | head -1)
  check "update exits 0" "AMC_RELEASE_URL=file://${ZIP:A} ./install.sh"
  check "a new process answers as $V" "answers ~/.amc/amc.sock $V && [[ \$(pgrep -f 'AgentsMissionControl.app/Contents/MacOS/' | head -1) != $pid ]]"
  print "== Remove"
  check "uninstall exits 0" "./uninstall.sh --yes"
  check "nothing left" "sleep 2; gone AgentsMissionControl co.tomac.amc ~/.amc"
else
  print "skip  release install: no release published yet and no zip given"
fi

if [[ -n $AMC_TEST_SOURCE ]]; then
  print "== Build from source (test channel)"
  check "source install exits 0" "AMC_CHANNEL=test ./install.sh"
  check "the test copy answers as $(<VERSION)" "answers ~/.amc-test/amc.sock $(<VERSION)"
  check "uninstall exits 0" "AMC_CHANNEL=test ./uninstall.sh --yes"
  check "nothing left" "sleep 2; gone AgentsMissionControl-test co.tomac.amc.test ~/.amc-test"
fi
rm -rf $T
(( fails )) && print "test-install: FAILED" || print "test-install: all passed"
exit $fails
