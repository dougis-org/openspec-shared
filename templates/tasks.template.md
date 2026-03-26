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

Verification requirements (all must pass before PR or pushing updates to a PR):

- **Unit tests** — run the project's unit test suite; all tests must pass
- **Integration tests** — run the project's integration test suite; all tests must pass
- **Regression / E2E tests** — run the project's end-to-end or regression test suite; all tests must pass
- **Build** — run the project's build script; build must succeed with no errors
- if **ANY** of the above fail, you **MUST** iterate and address the failure

Use the project's documented commands for each of the above (see project README or CLAUDE.md / AGENTS.md).

## PR and Merge

- [ ] Commit all changes to the working branch and push to remote
- [ ] Open PR from working branch to `<default-branch>`
- [ ] Wait for 120 seconds for the Agentic reviewers to post their comments
- [ ] **Monitor PR comments** — when comments appear, address them, commit fixes, follow all steps in [Remote push validation] then push to the same working branch; repeat until no unresolved comments remain
- [ ] Enable auto-merge once no blocking review comments remain
- [ ] **Monitor CI checks** — when any CI check fails, diagnose and fix the failure, commit fixes, follow all steps in [Remote push validation] then push to the same working branch; repeat until all checks pass
- [ ] Wait for the PR to merge — **never force-merge**; if a human force-merges, continue to Post-Merge

The comment and CI resolution loops are iterative: address → validate locally → push → re-check → repeat until the PR is fully clean. If a human force-merges before the PR is clean, proceed directly to Post-Merge steps.

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
- [ ] Sync approved spec deltas into `openspec/specs/` (global spec)
- [ ] Archive the change: move `openspec/changes/<name>/` to `openspec/changes/archive/YYYY-MM-DD-<name>/` **and stage both the new location and the deletion of the old location in a single commit** — do not commit the copy and delete separately
- [ ] Confirm `openspec/changes/archive/YYYY-MM-DD-<name>/` exists and `openspec/changes/<name>/` is gone
- [ ] Commit and push the archive to the default branch in one commit
- [ ] Prune merged local feature branches: `git fetch --prune` and `git branch -d <feature-branch>`

Required cleanup after archive: `git fetch --prune` and `git branch -d <feature-branch>`
