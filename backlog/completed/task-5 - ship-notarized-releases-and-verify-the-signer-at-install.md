---
id: task-5
title: Ship notarized releases and verify the signer at install
status: Done
assignee: [Iván González@amc-release-signing]
created_date: 2026-10-15
updated_date: 2026-10-31
labels: [trust]
dependencies: []
completed_date: 2026-10-31
---

## Description

Anyone can print the author's name; only a signature proves who built the app. Users who build from source sign it themselves or ad hoc. Publish a Developer ID-signed, notarized app per GitHub release; the installer downloads it and refuses one not signed by team Y4UQ4S5ANQ, and shows that check.

Notarizing needs hardened runtime. With it on, the app needs the entitlement `com.apple.security.automation.apple-events`, or Apple Events from its children (Automation, task-6) stop working.

## Acceptance Criteria

- [x] Each release has a notarized zip of the app
- [x] install.sh installs the release by default and verifies team Y4UQ4S5ANQ with codesign
- [x] Building from source stays available and is labelled as unsigned by the author

## Handoff

- 2026-10-31 15:43Z · Iván González@amc-release-signing · main: claimed. Next: close with release evidence
- 2026-10-31 15:43Z · Iván González@amc-release-signing · main: v0.3.0 released notarized; PR #3 merged; Codex reviewed twice, all findings fixed; CI green incl. release event Next: close

## Evidence

- `scripts/release.sh`
- `scripts/verify-app.sh`
- `tests/test-install.sh`
- https://github.com/tomacco/agents-mission-control/releases/tag/v0.3.0
- https://github.com/tomacco/agents-mission-control/actions/runs/41216155835

## Final Summary

v0.3.0 is the first signed, notarized release. install.sh downloads it, refuses anything scripts/verify-app.sh rejects (team Y4UQ4S5ANQ, co.tomac.amc, hardened runtime, notarized), stops every running copy and requires the new version to answer; re-running it is the update and also updates the plugin. --from-source builds locally. Reviewed by Codex in two passes (8 findings, all fixed). CI on macOS checks personal data, the verifier, install/update/remove, and on each published release downloads and installs it (run 41216155835 green).
