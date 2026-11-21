# Tasks

Process details (worktree, issue lifecycle, review, PR triage loop, archive) are defined in `skills/openspec-apply-change` and `skills/openspec-archive-change`. Follow them; do not restate them here.

Ownership: Implementer: | Reviewer(s): | Required approvals:

## Preparation

- [ ] Enter the change's worktree `.worktrees/<name>` (create from `origin/<default-branch>` if missing) and confirm the branch is pushed to remote

## Preflight

- [ ] Verify `pr-review-toolkit:review-pr` is available; if not, halt, tell the user the plugin is required with install guidance, and wait for confirmation

## Execution

One item per task: state how completion is verified and which `tests.md` cases it satisfies. Write the failing test first.

- [ ] Mark issue in-progress (skip if not issue-driven; apply skill, "Issue lifecycle")
- [ ] 1. <task> — verify: <command/observable>; tests: <case ids>
- [ ] 2. <task> — verify: <command/observable>; tests: <case ids>

Reuse existing project code before writing new logic.

## Pre-Commit Code Review

- [ ] Before every commit, run the `openspec-review-code` sub-agent and silently apply all clearly-correct findings, then re-run tests (first review covers the branch; later ones only changes since the last reviewed commit)

## Validation

- [ ] Run the repo's local equivalents of its CI checks: tests, build, lint/static analysis/type checks, security checks, and coverage requirements (docs-only change, i.e. every changed file is `.md`: build only). Use commands from the README / CLAUDE.md / AGENTS.md and CI config. All must pass before any push.
- [ ] All tasks above marked complete

## PR and Merge

- [ ] Commit, push, open PR to `<default-branch>`; body includes `Closes #N` for each linked issue
- [ ] Mark issue in-review (skip if not issue-driven)
- [ ] Run the apply skill's PR triage loop (review-pr sub-agent plus `gh pr checks --required --watch --fail-fast`; at most two fix iterations, then escalate)
- [ ] Enable auto-merge (`gh pr merge <PR-URL> --auto --merge`, never `--admin`) only after the triage loop is clean, then watch until `MERGED`
- [ ] Apply is complete only when the PR is merged with every required CI check and quality gate passing. Fix failures in code; never waive, lower, skip, or disable a check.

Blocking: CI failure, security finding, or unresolved review comment → fix → validate locally → push → re-check.

## Post-Merge

- [ ] Run `/opsx:archive` (spec sync, single-commit archive via doc-branch PR with auto-merge, worktree removal, branch prune)
