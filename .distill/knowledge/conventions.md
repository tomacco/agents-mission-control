---
domain: conventions
scope: commits, languages, style
last_validated: 2026-10-15
staleness_threshold: 90
---

# Conventions

## Commits
- Imperative subject, often prefixed with the area and a colon (`Caffeinate: …`, `Privileged sessions: …`); body explains why.
  evidence: git log -15 (4 of 9 subjects use `Area:`)
  confidence: provisional
  origin: convention
- Single branch `main`, no PR flow. evidence: git log (0 merges)
  confidence: provisional

## Languages
- Swift 5.10 tools, macOS 26+, SwiftUI with AppKit status item; no Xcode project. evidence: Package.swift
  confidence: hardened
  origin: constraint
- Shell scripts are **zsh** (`#!/bin/zsh`, `${0:A:h}` path idioms), never bash. evidence: bin/*, tests/*, build.sh, install.sh
  confidence: validated
- Plugin is TypeScript/TSX against the `claude-code` hooks API; JSX via `h`. evidence: mod/hooks/register.tsx
  confidence: validated

## Style
- Comments explain why, one or two lines above the code; no doc-comment blocks. evidence: Sources/*.swift
  confidence: provisional
- Menu bar art is pixel grids drawn live in SwiftUI `Canvas` (no PNG templates), so it follows light and dark. evidence: Bar.swift#Art
  confidence: validated
- No linter or formatter config in the repo. evidence: gather-evidence (no convention sources)
  confidence: validated
