# Agents Mission Control

A macOS menu bar app for working next to local coding agents. It shows whether agents may use your speakers and input devices, keeps the Mac awake, lists projects serving on localhost, and gives Claude Code agents Full Disk Access one approved session at a time, with a trace of every command.

Version 0.1.0. macOS 26 or later, Apple Silicon. MIT license.

## What it does

| Part | What it shows |
|---|---|
| Clawd | Orange with sound waves: agents may talk. Red with a pause sign: hands off, so no agent may speak, play sounds or drive the mouse and keyboard. |
| Cup | Faded when off; colored with time left (or ∞) when awake; yellow when the screen is kept on too. |
| Rack | Number of projects serving on localhost. The panel lists them; click a port to open it, right-click to stop it. |

Click Clawd to toggle hands off, anywhere else on the pill for the panel, right-click to quit.

## Install

```sh
git clone https://github.com/tomacco/agents-mission-control.git
cd agents-mission-control
./install.sh   # builds the app into ~/Applications, loads both LaunchAgents, registers the hands-off hook
```

Then install the Claude Code plugin. At the prompt of a Claude Code terminal session:

```
/plugin install amc --marketplace tomacco/agents-mission-control
```

From a shell: `claude plugin install amc --marketplace tomacco/agents-mission-control`. Answer `y` to add the marketplace, then pick the user scope.

To use privileged sessions, grant the app Full Disk Access once: System Settings > Privacy & Security > Full Disk Access, press +, choose `~/Applications/AgentsMissionControl.app`.

`build.sh` signs with the first "Developer ID Application" identity in your keychain. Without one the app is signed ad hoc, and macOS then forgets the Full Disk Access grant on every rebuild.

## Hands off

The panel only writes or removes `~/.amc/hands-off`. Two independent layers act on that flag:

1. `bin/amcd` (LaunchAgent `co.tomac.amc.amcd`) kills `say`, `afplay`, `uidriver` and `cliclick` within 0.25 s, for any process, Claude Code or not. Kills are logged to `~/Library/Logs/amcd.log`.
2. `hooks/hands-off-guard.sh` (Claude Code `PreToolUse` on Bash) refuses those commands and tells the agent to carry on headless, so agents do not retry in a loop.

From a shell: `bin/amcctl on | off | toggle | status`.

Known gap: a program that posts mouse events under a name outside the block list is not stopped. The fix is an event tap in the app that drops synthetic input while the flag is on, tracked in `docs/ROADMAP.md`.

## Privileged sessions

macOS grants Full Disk Access per app. Giving it to Terminal gives it to every process started from Terminal, forever. Here the app holds the grant instead, and runs an agent's commands as its own child processes, which inherit it. Terminal stays without it.

1. The `amc` plugin gives each Claude Code session the tool `privileged_bash` (command, reason, paths, agent name, subtitle).
2. The first call of a session opens a keyboard-first question: Allow for this session, Allow once, or Deny. The answer lives in the session's state only, so a new session always asks again.
3. While access is open, a pane beside the transcript shows a Clawd in a random color, the agent, the reason, the paths and each command's live output. Narrow terminals get a status line.
4. When a Bash or Read call fails with "Operation not permitted", the plugin tells the agent that `privileged_bash` exists.

Security model:

- The app listens on `~/.amc/amc.sock` (mode 0600) and accepts requests only from processes that descend from a Claude Code binary signed by Anthropic, checked against the running process.
- The first caller in a Claude Code process gets that process's key. The plugin asks for it at session start, before the model can run anything.
- Access ends with the approval scope, or when the session's `claude` process exits.
- Every request goes to `~/.amc/trace.jsonl` with the agent, reason, command, exit code and SHA-256 of the output. Each line holds the hash of the previous one. Output is kept in `~/.amc/runs/`.

Known gaps: any process running as you can read `~/.amc/runs`, and the logs are not expired yet. A plugin loaded late into a running session (hot reload) can lose the key to the agent.

## Tests

- `tests/test-hands-off.sh` runs against a private flag, so it never touches the live switch: a running driver dies, new speech dies before it is heard, the hook blocks voice, sound and input commands, ordinary commands still pass, and turning the switch off gives control back.
- `tests/test-privileged.sh` runs against the installed app, from a Claude Code session without the plugin (`! zsh tests/test-privileged.sh`): a caller outside Claude Code is refused, a bad key and a run without approval are refused, an approved command reads `~/Library/Mail` while Terminal still cannot, a one-time approval is used up, and the trace chain verifies.

## Development

- `AgentsMissionControl --preview` opens the pill and panel in a window for 6 s and prints its window number, for `screencapture -o -l <n>` without clicking the menu bar.
- `claude --plugin-dir mod` runs a session with the plugin loaded from this checkout.
- `swiftbar/` holds the original SwiftBar plugins. The caffeinate tile calls `swiftbar/caffeinate/caffeinate.5s.sh start|stop`, so runs started from either place are recognised.
