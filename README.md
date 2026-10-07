# Helm

One menu bar pill for working next to local coding agents: Clawd │ caffeinate │ localhost. Click Clawd to toggle hands off; click anywhere else for the Liquid Glass panel; right-click to quit.

The pill uses the full 22 pt a status item gets on this Mac (the bar is 33 pt) and grows sideways. Everything right of the notch shares 663 pt, so a full bar pushes new items behind the overflow chevron.

| Part | What it shows |
|---|---|
| Clawd | Orange with sound waves: agents may talk. Red with a pause sign: hands off, so no agent may speak, play sounds or drive the mouse and keyboard. |
| Cup | Faded when off; orange with time left (or ∞) when awake; yellow when the screen is kept on too. |
| Rack | Number of projects serving on localhost. The panel lists them; click a port to open it, right-click to stop it. |

## How hands off works

The panel only writes or removes `~/.helm/hands-off`. Two independent layers act on that flag:

1. `bin/helmd` (LaunchAgent `co.tomac.helm.helmd`) kills `say`, `afplay`, `uidriver` and `cliclick` within 0.25 s, for any process, Claude Code or not. Kills are logged to `~/Library/Logs/helmd.log`.
2. `hooks/hands-off-guard.sh` (Claude Code `PreToolUse` on Bash) refuses those commands and tells the agent to carry on headless, so agents do not retry in a loop.

From a shell: `bin/helmctl on | off | toggle | status`.

Proof: `tests/test-hands-off.sh` runs against a private flag, so it never touches the live switch. It checks that a running driver dies, that new speech dies before it is heard, that the hook blocks voice, sound and input commands, that ordinary commands still pass, and that turning the switch off gives control back.

Known gap: a program that posts mouse events under a name outside the block list is not stopped. The structural fix is an event tap in Helm that drops synthetic input while the flag is on (needs Accessibility), tracked in `docs/ROADMAP.md`.

## Install

```sh
./install.sh   # builds Helm.app into ~/Applications, loads both LaunchAgents, registers the hook
```

`Helm --preview` opens the pill and panel in a window for 6 s and prints its window number, for `screencapture -o -l <n>` without clicking the menu bar.

The original SwiftBar plugins live in `swiftbar/`. Caffeinate tile calls `swiftbar/caffeinate/caffeinate.5s.sh start|stop`, so runs started from either place are recognised as ours.
