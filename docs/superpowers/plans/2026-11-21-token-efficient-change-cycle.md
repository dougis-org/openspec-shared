# Token-efficient change cycle Implementation Plan

> **For agentic workers:** executed natively, inline (user said "go ahead and build it").

**Goal:** Cut per-change tokens without weakening gates; add tool-agnostic CI definition of done for apply.
**Spec:** `docs/superpowers/specs/2026-11-21-token-efficient-change-cycle-design.md`

## Global Constraints
- `skills/` is canonical; surfaces regenerated via `sh sync-surfaces.sh`; `templates/` kept and mirrors schema templates (tasks/design/tests).
- No artifact graph change; `tests.md` stays.
- No tool names or numeric thresholds in CI/quality rules.

## Tasks
1. Slim `openspec/schemas/.../templates/tasks.md`; mirror to `templates/tasks.template.md`.
2. Trim `design.md` template (single traceability home) and `tests.md` template; mirror to `templates/`.
3. Rewrite `config.yaml` tasks/design/spec rules (short, pointer to skills, CI definition of done); trim `schema.yaml` instruction for tasks.
4. Rewrite `skills/openspec-apply-change/SKILL.md` (steps renumbered, cheaper PR loop, CI DoD, minimal context reads, post-merge delegates to archive).
5. Update `skills/openspec-review-code/SKILL.md` (optional base SHA, incremental diff).
6. Fix `skills/openspec-propose/SKILL.md` (duplicate paragraph, specs listed, pointer-only tasks guidance).
7. Update `USAGE.md`/`README.md` to reference rather than restate; report byte counts before/after.

## Verification
- `wc -c` before/after on files loaded per change.
- grep: no duplicate step numbers in apply skill; no tool names in CI rules; `180`/`auto-merge` rule stated once in skills.
