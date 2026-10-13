#!/bin/zsh
# Claude Code PreToolUse hook (Bash). While hands-off is on, refuse commands that speak, play
# sounds or drive the mouse/keyboard, and tell the agent to carry on headless without retrying.
FLAG=${HELM_FLAG:-$HOME/.helm/hands-off}
[[ -e $FLAG ]] || exit 0
cmd=$(/usr/bin/plutil -extract tool_input.command raw -o - - 2>/dev/null)
if print -r -- "$cmd" | /usr/bin/grep -Eq '(^|[^[:alnum:]_-])(say|afplay|cliclick|uidriver|ui-check(\.sh)?)([^[:alnum:]_-]|$)|osascript.*(say |click|keystroke|key code)'; then
  print -u2 "Hands-off is ON: Ivan has blocked agents from speaking, playing sounds or using the mouse/keyboard (Helm panel). Do not retry or work around it. Continue headless work, and leave GUI checks and audio cues for when he turns it off (check with ~/git/github.com/tomacco/helm/bin/helmctl status)."
  exit 2
fi
exit 0
