# agents-mission-control — Knowledge Spine

<!-- repo-distill Tier-1 index. Max 80 lines. Pointers only, NO content. -->

_Last full distillation: 2026-10-15 · repo state: v0.1.0_

## Knowledge
- [Architecture](knowledge/architecture.md) — the app, scripts, hook, plugin and where state lives; read before touching cross-cutting code or adding a component.
- [Conventions](knowledge/conventions.md) — commit format, script language, code style; read before writing code or committing.
- [Workflows](knowledge/workflows.md) — build, install, test, preview, plugin checks, release; read before running or shipping anything.
- [Gotchas](knowledge/gotchas.md) — traps that cost time here; read before debugging, installing or testing.
- [Glossary](knowledge/glossary.md) — hands off, lease, key, trace, mod; read when a term is unfamiliar.

Review culture is not distilled: one author, no merge commits (evidence: git log, 9 commits, 0 merges).

## Provenance & freshness
- Every fact in the files above carries an `evidence:` source and `confidence:`. See `sources.yml`.
- Generated (do not hand-edit): the `repo-distill` block in `AGENTS.md`, and `.github/copilot-instructions.md`. Text outside the block is yours.
- Freshness is enforced by `scripts/check-freshness.sh` (pre-commit and CI).
