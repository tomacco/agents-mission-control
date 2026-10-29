---
id: task-6
title: Charge Automation (Apple Events) to AMC, not Terminal
status: Done
assignee: [Iván González@agents-mission-control]
created_date: 2026-10-29
updated_date: 2026-10-29
labels: [trust]
dependencies: []
completed_date: 2026-10-29
---

## Description

Agents that drive another app with osascript run from Terminal, so macOS charges the Automation grant to Terminal. AMC's children should carry it instead.

## Acceptance Criteria

- [ ] build.sh writes NSAppleEventsUsageDescription and fails the build without it
- [ ] The plugin points an agent at privileged_bash on an Apple Events denial (-1743)
- [ ] A test copy shows a macOS Automation prompt naming the test app, and TCC.db holds its row, not a new Terminal row
- [ ] tests/test-privileged.sh passes

## Handoff

- 2026-10-29 14:53Z · Iván González@agents-mission-control · automation-apple-events: claimed. Next: Show -1743 on a test build without the key, then add the key
- 2026-10-29 15:00Z · Iván González@agents-mission-control · automation-apple-events: Key added and asserted in build.sh; plugin routes -1743; test copy proof done: no-key build prompted (named test app), keyed build prompted with the new text, tccutil shows co.tomac.amc.test granted, Terminal AppleEvents counts unchanged (8 by bundle, 9 by service). test-privileged 7/0, plugin tests 10/0. Next: Owner unticks Excel under Terminal in Automation; push when the owner says.

## Evidence

- `build.sh`
- `mod/hooks/register.tsx`
- `mod/tests/pane.test.tsx`
- `.distill/knowledge/gotchas.md`

## Final Summary

Automation from AMC's children is charged to AMC. On the test copy (co.tomac.amc.test) an Apple event to Excel through a Touch ID lease raised a macOS prompt naming the test app; tccutil list -s AppleEvents -b co.tomac.amc.test = granted, Terminal's AppleEvents record counts did not change. The expected -1743 without the key did not happen: without hardened runtime macOS prompts anyway, so the key sets the prompt text and is kept for hardened runtime (task-5 note). The per-user TCC.db does not exist on macOS 27.2, so TCC.db rows could not be shown; tccutil is the evidence.
