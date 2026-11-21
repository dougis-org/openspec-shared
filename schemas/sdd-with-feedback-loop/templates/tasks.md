# Tasks

Process details (PR loop, review, archive) live in `skills/openspec-apply-change` and `skills/openspec-archive-change`; follow them rather than restating them here.

Ownership: Implementer: | Reviewer(s): | Required approvals:

## Preparation

- [ ] Checkout `<default-branch>`, `git pull --ff-only`, create `<feature-branch-name>`, then `git push -u origin <feature-branch-name>`

## Execution

One item per task, each naming the `tests.md` case(s) it satisfies. Write the failing test first (see `tests.md`).

- [ ] 1. <task> — tests: <case ids>
- [ ] 2. <task> — tests: <case ids>

Reuse existing project code before writing new logic.

## Pre-Commit Code Review

- [ ] Before every commit, run the `openspec-review-code` sub-agent and fix all findings (incremental review after the first)

## Validation

- [ ] Run the repo's local equivalents of its CI checks: tests, build, lint/static analysis, security checks, and coverage requirements. All must pass before any push. Use the commands in the project README / CLAUDE.md / AGENTS.md and CI config.
- [ ] All tasks above marked complete

## PR and Merge

- [ ] Open PR to `<default-branch>`; body includes `Closes #N` for each issue in `proposal.md`
- [ ] Enable auto-merge immediately (never `--admin`), then run the apply skill's PR loop until merged
- [ ] Apply stage is complete only when the PR is merged with every required CI check and quality gate passing. Fix failures in code; never waive, lower, skip or disable a check.

Blocking: CI failure, security finding, or unresolved review comment → fix → validate locally → push → re-check.

## Post-Merge

- [ ] Run `/opsx:archive` (spec sync, single-commit archive via doc-branch PR with auto-merge, branch prune)
