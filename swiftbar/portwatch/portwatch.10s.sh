#!/bin/zsh
# <swiftbar.title>Portwatch</swiftbar.title>
# <swiftbar.desc>Local dev servers: which project serves on which port.</swiftbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>
#
# A listener counts as a "project" when its process runs from a directory under $HOME
# (system and GUI apps run from /, agent CLIs from $HOME itself). Name = git repo or folder name.
export PATH=/usr/bin:/bin:/usr/sbin:/opt/homebrew/bin

typeset -A seen
rows=()
pid= cmd=
while IFS= read -r line; do
  case $line in
    p*) pid=${line#p} ;;
    c*) cmd=${line#c} ;;
    n*)
      port=${line##*:}
      [[ -n ${seen[$port]} ]] && continue
      seen[$port]=1
      cwd=$(lsof -a -p $pid -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
      [[ $cwd == $HOME/* ]] || continue
      top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
      name=${${top:-$cwd}:t}
      title=$(curl -s -m 0.5 "http://127.0.0.1:$port/" 2>/dev/null \
        | tr '\n' ' ' | sed -n 's/.*<title[^>]*>\([^<]*\)<\/title>.*/\1/Ip' | cut -c1-40)
      rows+=("$name|$port|$pid|$cmd|$cwd|$title")
      ;;
  esac
done < <(lsof -nP -iTCP -sTCP:LISTEN -Fpcn 2>/dev/null)

rows=(${(o)rows})
here=${0:A:h}
if (( ${#rows} )); then
  echo "${#rows} | templateImage=$(base64 -i $here/icon.png)"
else
  echo " | templateImage=$(base64 -i $here/icon-idle.png)"
fi
echo "---"
(( ${#rows} )) || echo "Nothing served from ~ | color=gray"
for r in $rows; do
  IFS='|' read -r name port pid cmd cwd title <<< "$r"
  label="$name  :$port"
  [[ -n $title ]] && label+="  · $title"
  echo "$label | href=http://localhost:$port font=Menlo size=13 tooltip=${cwd/#$HOME/~}"
  echo "Kill $name ($cmd, pid $pid) | alternate=true color=#d9534f bash=/bin/kill param1=$pid terminal=false refresh=true"
done
echo "---"
echo "Click opens · ⌥ to kill | color=gray size=11"
echo "Refresh | refresh=true"
