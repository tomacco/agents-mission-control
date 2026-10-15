# Agents Mission Control

Full Disk Access for Claude Code agents on macOS, one session at a time, approved with Touch ID, with a trace of every command.

Version 0.2.0. macOS 26 or later, Apple Silicon. MIT license. By Ivan Gonzalez (tomacco) · [tomac.co](https://tomac.co)

## Why

macOS grants Full Disk Access per app. Giving it to Terminal gives it to every process started from Terminal, forever. Agents Mission Control holds the grant instead and runs an agent's commands as its own child processes, which inherit it. Terminal stays without it, and every session needs your fingerprint.

## Install

```sh
git clone https://github.com/tomacco/agents-mission-control.git
cd agents-mission-control
./install.sh
```

The installer builds the app, starts it at login, shows who signed it, and walks you through the one step macOS leaves to you: switching on Full Disk Access. It explains the step before it opens System Settings and Finder, then waits and carries on by itself.

Then install the Claude Code plugin. At the prompt of a Claude Code terminal session:

```
/plugin install amc --marketplace tomacco/agents-mission-control
```

From a shell: `claude plugin install amc --marketplace tomacco/agents-mission-control`. Answer `y` to add the marketplace, then pick the user scope.

The app has no menu bar item and no window. Everything you see happens in the installer and in Claude Code.

`build.sh` signs with the first "Developer ID Application" identity in your keychain. Without one the app is signed ad hoc, and macOS then forgets the Full Disk Access grant on every rebuild.

## How it works

1. The `amc` plugin gives each Claude Code session the tool `privileged_bash` (command, reason, paths, agent name, subtitle).
2. The first call of a session makes the app ask you for Touch ID (or your password), showing the agent, the reason and the paths. That approval covers the session and ends with it.
3. While access is open, a pane beside the transcript shows the agent, the reason, the paths and each command's live output. Narrow terminals get a status line.
4. When a Bash or Read call fails with "Operation not permitted", the plugin tells the agent that `privileged_bash` exists.
5. `/amc` shows the pane on demand: whether the session has access, whether the app has Full Disk Access, and the latest runs. The pane closes by itself 90 s after the last run.

## Security model

- The app listens on `~/.amc/amc.sock` (mode 0600) and accepts requests only from processes that descend from a Claude Code binary signed by Anthropic, checked against the running process.
- Only a person opens access: the app asks for Touch ID or the login password. An agent can reach the socket and could post synthetic clicks, but it cannot pass Touch ID.
- Access ends with the approval scope, or when the session's `claude` process exits.
- Commands run with `pipefail`, so a failure anywhere in a pipe shows in the exit code.
- Every request goes to `~/.amc/trace.jsonl` with the agent, reason, command, exit code and SHA-256 of the output. Each line holds the hash of the previous one. Output is kept in `~/.amc/runs/`.

Known gap: any process running as you can read `~/.amc/runs`, and the logs are not expired yet.

## Remove

```sh
./uninstall.sh     # the app, its LaunchAgent, ~/.amc and every permission macOS gave it
```

In Claude Code: `/plugin uninstall amc`.

## Tests

- `tests/test-privileged.sh` runs against the installed app from a Claude Code session (`! zsh tests/test-privileged.sh`): a caller outside Claude Code and a run without approval are refused, and the trace chain verifies. With `--touch-id` it also approves twice and checks that an approved command reads `~/Library/Mail` while Terminal still cannot, that a one-time approval is used up, and that pipe failures show.
- `tests/test-grant-order.sh` checks that the grant step leaves System Settings in front of Finder.
- `tests/try-install.sh` tries the whole install as a new user with a separate test copy, then removes it.

## Credits

The orb shown while Touch ID waits is drawn with the geometry engine of [thinking-orbs](https://libraries.dev/orbs) by Jakub Antalik, MIT license, vendored in `mod/vendor/thinking-orbs` with its license.

## Related

[Agent Board](https://github.com/tomacco/agent-board) is the menu bar companion that used to live in this repository: hands off (agents may not speak, play sounds or drive input), caffeinate and the localhost list.
