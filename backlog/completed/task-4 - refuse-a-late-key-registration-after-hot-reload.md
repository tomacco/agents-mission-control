---
id: task-4
title: Refuse a late key registration after hot reload
status: Done
assignee: []
created_date: 2026-10-15
updated_date: 2026-10-15
labels: [privileged]
dependencies: []
completed_date: 2026-10-15
---

## Description

If the plugin loads after the model ran commands, the agent may have taken the session key.

## Acceptance Criteria

- [ ] The plugin detects a key it did not get and tells the person

## Handoff

- 2026-10-15 10:01Z · Iván González@agents-mission-control · main: Superseded: session keys removed; Touch ID in the app is the approval (decision-3) Next: none

## Evidence

- `Sources/AgentsMissionControl/Privileged.swift`

## Final Summary

Superseded by decision-3: session keys removed, the app asks for Touch ID before any lease opens. The late-install race no longer matters.
