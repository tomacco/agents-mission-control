# Agents Mission Control: agent notes

- Swift package (`Sources/AgentsMissionControl`), built into an app bundle by `build.sh`; no Xcode project yet. `install.sh` is idempotent.
- The panel never enforces anything itself. Enforcement is `bin/amcd` plus `hooks/hands-off-guard.sh`; keep it that way so phase 2 controls only have to flip the flag.
- Any change to the block list or the hook pattern must pass `tests/test-hands-off.sh`, including the "allows" cases.
- Check layout with `build/AgentsMissionControl.app/Contents/MacOS/AgentsMissionControl --preview` and capture the printed window number. Never click the menu bar to test it: synthetic input while Ivan may be at the keyboard is not allowed.
- If hands off is on (`bin/amcctl status`), do not speak, play sounds or drive input. Do not turn it off yourself.
