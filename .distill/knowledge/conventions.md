---
domain: conventions
scope: commits, languages, style
last_validated: 2026-10-15
staleness_threshold: 90
---

# Conventions

## Commits
- Imperative subject, often prefixed with the area and a colon; body explains why. evidence: git log
  confidence: provisional
  origin: convention

## Languages
- Swift 5.10 tools, macOS 26+, AppKit; no Xcode project. evidence: Package.swift
  confidence: hardened
  origin: constraint
- Shell scripts are **zsh**, never bash. evidence: install.sh, tests/*.sh
  confidence: validated
- Installer UI is Python 3 standard library only (`/usr/bin/python3 -I`). evidence: tools/installer.py
  confidence: validated
- Plugin is TypeScript/TSX against the `claude-code` hooks API; JSX via `h`. evidence: mod/hooks/register.tsx
  confidence: validated

## Style
- Comments explain why, one or two lines above the code. evidence: Sources/*.swift
  confidence: provisional
- Terminal art draws each pixel as two columns of background color (half-block glyphs leave seams in Terminal.app). evidence: tools/installer.py#lock_rows
  confidence: validated
- Product text names the author: Ivan Gonzalez (tomacco) · tomac.co. evidence: tools/installer.py, README.md
  confidence: validated
  origin: directive
