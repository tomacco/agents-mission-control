# Helm

Three menu bar icons for working next to local coding agents. Each icon is Clawd plus a small sign of its status; the panels use Liquid Glass.

| Tile | What it does |
|---|---|
| Hands off | Clawd with sound waves = agents may talk; red Clawd with a pause sign = hands off. One left click stops every local agent from speaking, playing sounds or driving the mouse and keyboard. Click again to give control back. Right click for Quit. |
| Caffeinate | Keeps the Mac awake (∞, 30m, 1h, 2h), or awake with the screen on. |
| Localhost | Dev servers started from a project under `~`, one row per project. Click a port to open it, right-click to stop it. |

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

`Helm --preview` opens the panels in a window for 6 s and prints its window number, for `screencapture -o -l <n>` without clicking the menu bar. Icons: `swift make-icons.swift assets`.

The original SwiftBar plugins live in `swiftbar/`. Caffeinate tile calls `swiftbar/caffeinate/caffeinate.5s.sh start|stop`, so runs started from either place are recognised as ours.
