---
id: task-5
title: Ship notarized releases and verify the signer at install
status: To Do
assignee: []
created_date: 2026-10-15
updated_date: 2026-10-15
labels: [trust]
dependencies: []
---

## Description

Anyone can print the author's name; only a signature proves who built the app. Users who build from source sign it themselves or ad hoc. Publish a Developer ID-signed, notarized app per GitHub release; the installer downloads it and refuses one not signed by team Y4UQ4S5ANQ, and shows that check.

## Acceptance Criteria

- [ ] Each release has a notarized zip of the app
- [ ] install.sh installs the release by default and verifies team Y4UQ4S5ANQ with codesign
- [ ] Building from source stays available and is labelled as unsigned by the author

## Handoff

## Evidence

## Final Summary
