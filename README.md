# Agents Mission Control

One menu bar pill for working next to local coding agents: Clawd │ caffeinate │ localhost. Click Clawd to toggle hands off; click anywhere else for the Liquid Glass panel; right-click to quit.

The pill uses the full 22 pt a status item gets on this Mac (the bar is 33 pt) and grows sideways. Everything right of the notch shares 663 pt, so a full bar pushes new items behind the overflow chevron.

| Part | What it shows |
|---|---|
| Clawd | Orange with sound waves: agents may talk. Red with a pause sign: hands off, so no agent may speak, play sounds or drive the mouse and keyboard. |
| Cup | Faded when off; orange with time left (or ∞) when awake; yellow when the screen is kept on too. |
| Rack | Number of projects serving on localhost. The panel lists them; click a port to open it, right-click to stop it. |

## How hands off works

The panel only writes or removes `~/.amc/hands-off`. Two independent layers act on that flag:

1. `bin/amcd` (LaunchAgent `co.tomac.amc.amcd`) kills `say`, `afplay`, `uidriver` and `cliclick` within 0.25 s, for any process, Claude Code or not. Kills are logged to `~/Library/Logs/amcd.log`.
2. `hooks/hands-off-guard.sh` (Claude Code `PreToolUse` on Bash) refuses those commands and tells the agent to carry on headless, so agents do not retry in a loop.

From a shell: `bin/amcctl on | off | toggle | status`.

Proof: `tests/test-hands-off.sh` runs against a private flag, so it never touches the live switch. It checks that a running driver dies, that new speech dies before it is heard, that the hook blocks voice, sound and input commands, that ordinary commands still pass, and that turning the switch off gives control back.

Known gap: a program that posts mouse events under a name outside the block list is not stopped. The structural fix is an event tap in the app that drops synthetic input while the flag is on (needs Accessibility), tracked in `docs/ROADMAP.md`.

## Privileged sessions (Full Disk Access for agents)

Terminal keeps no Full Disk Access. This app holds the grant and runs an agent's approved commands as its own child processes, which inherit it.

1. The `amc` mod (`mod/`) gives each Claude Code session the tool `privileged_bash` (command, reason, paths, agent name, subtitle).
2. The first call of a session opens a keyboard-first question: Allow for this session, Allow once, or Deny. The answer lives in the session's state only, so a new session always asks again.
3. While access is open, a pane beside the transcript shows a Clawd in a random color, the agent, the reason, the paths and each command's live output. Narrow terminals get a status line.
4. The app accepts requests on `~/.amc/amc.sock` only from processes that descend from Claude Code signed by Anthropic, checked on the running process. Each session gets a key on its first request, and leases end when its `claude` process exits.
5. Every request is written to `~/.amc/trace.jsonl` with the agent, reason, command, exit code and SHA-256 of the output. Each line holds the hash of the previous one. Output stays in `~/.amc/runs/`.

The app is signed with the Developer ID so the grant survives rebuilds. Grant it once in System Settings > Privacy & Security > Full Disk Access (add `~/Applications/AgentsMissionControl.app` with +).

Proof: `tests/test-privileged.sh`, run from a Claude Code session without the mod (`! zsh tests/test-privileged.sh`). Use the mod in a session: `claude --plugin-dir ~/git/github.com/tomacco/agents-mission-control/mod`.

Known gap: any process running as this user can read the session's run logs in `~/.amc/runs`, and an agent can register first in a session where the mod loaded late (hot reload). The mod registers at session start to close that window.

## Install

```sh
./install.sh   # builds AgentsMissionControl.app into ~/Applications, loads both LaunchAgents, registers the hook
```

`AgentsMissionControl --preview` opens the pill and panel in a window for 6 s and prints its window number, for `screencapture -o -l <n>` without clicking the menu bar.

The original SwiftBar plugins live in `swiftbar/`. Caffeinate tile calls `swiftbar/caffeinate/caffeinate.5s.sh start|stop`, so runs started from either place are recognised as ours.
