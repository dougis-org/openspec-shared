# Tasks

## Preparation

- [ ] **Step 1 — Sync default branch:** `git checkout <default-branch>` and `git pull --ff-only`
- [ ] **Step 2 — Create and publish working branch:** `git checkout -b <feature-branch-name>` then immediately `git push -u origin <feature-branch-name>`

## Execution

- [ ] Implement sub-tasks in small, testable increments
- [ ] Review for duplication and unnecessary complexity
- [ ] Confirm acceptance criteria are covered

Suggested start-of-work commands: `git checkout <default-branch>` → `git pull --ff-only` → `git checkout -b <feature-branch-name>` → `git push -u origin <feature-branch-name>`

## Validation

- [ ] Run unit/integration tests
- [ ] Run E2E tests (if applicable)
- [ ] Run type checks
- [ ] Run build
- [ ] Run security/code quality checks required by project standards
- [ ] All completed tasks marked as complete
- [ ] All steps in [Remote push validation]

## Remote push validation

Before running, determine whether the current change is **docs-only**: run `git diff --name-only HEAD` (or compare the working branch against the base branch) and check whether every changed file ends in `.md`. If yes, apply the docs-only path; otherwise apply the full path.

**Full path** (any non-`.md` file changed):

- **Unit tests** — run the project's unit test suite; all tests must pass
- **Integration tests** — run the project's integration test suite; all tests must pass
- **Regression / E2E tests** — run the project's end-to-end or regression test suite; all tests must pass
- **Build** — run the project's build script; build must succeed with no errors

**Docs-only path** (every changed file is `.md`):

- **Build** — run the project's build script; build must succeed with no errors
- Skip integration and regression/E2E tests — they are not required when no code changed

If **ANY** required step fails, you **MUST** iterate and address the failure before pushing.

Use the project's documented commands for each of the above (see project README or CLAUDE.md / AGENTS.md).

## PR and Merge

- [ ] Run the required pre-commit review from `skills/openspec-apply-change/SKILL.md` before committing, ensuring the primary agent automatically addresses all findings from the sub-agent
- [ ] Commit all changes to the working branch and push to remote
- [ ] Open PR from working branch to `<default-branch>`
- [ ] Open the PR, then immediately start both in parallel (no fixed sleeps): (a) spawn a sub-agent to run `pr-review-toolkit:review-pr`; (b) run `gh pr checks <PR-URL> --required --watch --fail-fast` (returns on the first failure or when all required checks finish)
- [ ] **Triage loop — repeat until review-pr reports zero findings, all required checks pass, and no review thread is unresolved.** Each iteration, collect every signal at once, then fix everything in a single commit:
  1. **Failing required checks** — `gh pr checks <PR-URL> --required --json name,bucket,link`; for failures, `gh run view <run-id> --log-failed`
  2. **Unresolved review threads** — `gh api graphql` on `pullRequest.reviewThreads` (`id isResolved isOutdated path comments`), paginating with `pageInfo.endCursor`. (`gh pr view --json` has no `reviewThreads` field.)
  3. **review-pr findings** — from the sub-agent started above
  Then: run [Remote push validation], push once, reply to and resolve each addressed thread immediately (`resolveReviewThread` mutation), and re-run `gh pr checks ... --watch --fail-fast`. **Iterate at most twice.** After two fix-and-push iterations, run a third review; if it (review-pr findings, required checks, or review threads) still raises issues, stop, escalate to the user with the remaining items listed, and wait for guidance. Do not start a fourth iteration.
- [ ] **Enable auto-merge only after the triage loop is clean:** `gh pr merge <PR-URL> --auto --merge` (NEVER use `--admin` to force the merge)
- [ ] **Watch for merge** — poll `gh pr view <PR-URL> --json state` (pairing with `gh pr checks --watch`, not fixed sleeps) until `MERGED`; if `CLOSED`, exit and notify the user. If new comments or check failures appear after auto-merge is enabled, re-enter the triage loop. Never wait for a human to report the merge; never force-merge.

After every push, restart the triage loop. Never skip the build/test gate before pushing any fix.

Ownership metadata:

- Implementer:
- Reviewer(s):
- Required approvals:

Blocking resolution flow:

- CI failure → fix → commit → validate locally → push → re-run checks
- Security finding → remediate → commit → validate locally → push → re-scan
- Review comment → address → commit → validate locally → push → confirm resolved

## Post-Merge

- [ ] `git checkout <default-branch>` and `git pull --ff-only`
- [ ] Verify the merged changes appear on the default branch
- [ ] Mark all remaining tasks as complete (`- [x]`)
- [ ] Update repository documentation impacted by the change
- [ ] Sync approved spec deltas into `openspec/specs/` (global spec). After copying each `spec.md` to `openspec/specs/<cap>/spec.md`, update all relative links that pointed into the change directory so they resolve from the archive location — replace `../../design.md` with `../../changes/archive/YYYY-MM-DD-<name>/design.md`, and similarly for `../../tasks.md` and any other relative paths into the change directory.
- [ ] Archive the change: move `openspec/changes/<name>/` to `openspec/changes/archive/YYYY-MM-DD-<name>/` **and stage both the new location and the deletion of the old location in a single commit** — do not commit the copy and delete separately
- [ ] Confirm `openspec/changes/archive/YYYY-MM-DD-<name>/` exists and `openspec/changes/<name>/` is gone
- [ ] Commit and push the archive to the default branch in one commit
- [ ] Prune merged local feature branches: `git fetch --prune` and `git branch -D <feature-branch>`

Required cleanup after archive: `git fetch --prune` and `git branch -D <feature-branch>`
