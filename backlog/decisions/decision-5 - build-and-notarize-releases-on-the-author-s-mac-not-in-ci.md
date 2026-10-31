---
id: decision-5
title: Build and notarize releases on the author's Mac, not in CI
date: 2026-10-31
status: accepted
origin: evidence
tasks: []
---

## Context

Releases must be signed with the Developer ID of team Y4UQ4S5ANQ and notarized. The certificate and its private key live in the author's login keychain; the App Store Connect API key is in ~/.appstoreconnect.

## Options Considered

1) scripts/release.sh on the author's Mac. 2) A GitHub Actions job with the .p12 and API key stored as repository secrets.

## Decision

Option 1. Exporting the signing key to a public repository's CI widens who can sign as the author for a project with one maintainer. CI still checks every published release: it downloads, verifies and installs it on a clean Mac. Revisit when a second maintainer ships releases.

## Evidence

- `scripts/release.sh`
- `.github/workflows/checks.yml`

## Consequences
