#!/bin/zsh
# <swiftbar.title>Caffeinate</swiftbar.title>
# <swiftbar.desc>Keep the Mac (and optionally the screen) awake; shows caffeinate runs started elsewhere.</swiftbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>
#
# Our run is started as `exec -a caffeinate-bar caffeinate ...`, so `ps` shows it as caffeinate-bar
# and every other caffeinate on the box is "external".
export PATH=/usr/bin:/bin:/usr/sbin
exec 2>>~/Library/Logs/caffeinate-bar.log  # stderr of every run; SwiftBar keeps none
NAME=caffeinate-bar

ours() { ps -axo pid=,args= | awk -v n=$NAME '$2 == n { print $1 }'; }

case $1 in
  start)  # start <flags> [seconds]
    ours | xargs kill 2>/dev/null
    (exec -a $NAME /usr/bin/caffeinate $2 ${3:+-t $3}) >/dev/null 2>&1 &!
    exit ;;
  stop) ours | xargs kill 2>/dev/null; exit ;;
esac

secs() {  # ps etime [[dd-]hh:]mm:ss -> seconds
  local t=$1 d=0 p
  [[ $t == *-* ]] && { d=${t%%-*}; t=${t#*-}; }
  p=(${(s.:.)t}); (( ${#p} == 2 )) && p=(0 $p)
  echo $(( d*86400 + 10#${p[1]}*3600 + 10#${p[2]}*60 + 10#${p[3]} ))
}
fmt() { (( $1 >= 3600 )) && echo "$(( $1/3600 ))h$(( $1%3600/60 ))m" || echo "$(( ($1+59)/60 ))m"; }

mine= ext=()
while read -r pid ppid etime comm args; do
  if [[ $comm == $NAME ]]; then
    mine="$pid|$etime|$args"
  elif [[ ${comm:t} == caffeinate ]]; then
    parent=$(ps -o comm= -p $ppid 2>/dev/null); parent=${${parent:t}#-}
    (( ppid == 1 )) && parent="orphan"
    ext+=("$pid|$etime|${parent:-?}|$args")
  fi
done < <(ps -axo pid=,ppid=,etime=,comm=,args=)

me=${0:A}
here=${me:h}
item() { echo "$1 | bash=$me param1=start param2=$2 ${3:+param3=$3} terminal=false refresh=true"; }

if [[ -n $mine ]]; then
  IFS='|' read -r pid etime args <<< "$mine"
  [[ $args == *-d* ]] && { mode="Screen on"; color="#FFD60A"; icon=screen; } \
                      || { mode="Awake"; color="#FF9F0A"; icon=awake; }
  left=
  if [[ $args =~ '-t ([0-9]+)' ]]; then
    rem=$(( match[1] - $(secs $etime) )); (( rem > 0 )) && left=$(fmt $rem)
  fi
  echo "${left} | image=$(base64 -i $here/icon-$icon.png)"
  echo "---"
  echo "$mode · ${left:+$left left}${${left:+}:-until stopped} | color=$color"
  echo "Stop | bash=$me param1=stop terminal=false refresh=true"
elif (( ${#ext} )); then
  echo " | image=$(base64 -i $here/icon-external.png)"
  echo "---"
  echo "Off (kept awake by another caffeinate) | color=gray"
else
  echo " | templateImage=$(base64 -i $here/icon-off.png)"
  echo "---"
  echo "Off | color=gray"
fi

echo "---"
echo "Keep awake"
item "--Until stopped" -i
item "--30 minutes" -i 1800; item "--1 hour" -i 3600; item "--2 hours" -i 7200
echo "Keep awake + screen on"
item "--Until stopped" -di
item "--30 minutes" -di 1800; item "--1 hour" -di 3600; item "--2 hours" -di 7200

echo "---"
echo "Other caffeinate runs (${#ext}) | color=gray size=11"
for e in $ext; do
  IFS='|' read -r pid etime parent args <<< "$e"
  flags=${${args#*caffeinate}## }
  echo "$parent: ${flags:-(no flags)}  · ${etime} | font=Menlo size=12 tooltip=pid $pid"
  echo "Kill pid $pid ($parent) | alternate=true color=#d9534f bash=/bin/kill param1=$pid terminal=false refresh=true"
done
(( ${#ext} )) && echo "⌥ to kill | color=gray size=11"
exit 0  # the && above returns 1 when no other runs exist, which SwiftBar shows as an error
