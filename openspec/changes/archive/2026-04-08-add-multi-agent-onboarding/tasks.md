# Tasks

## Preparation

- [x] **Step 1 — Sync default branch:** `git checkout <default-branch>` and `git pull --ff-only`
- [x] **Step 2 — Create and publish working branch:** `git checkout -b feat/multi-agent-onboarding` then immediately `git push -u origin feat/multi-agent-onboarding`
- [x] Confirm the target support matrix for default onboarding: `.codex/`, `.claude/`, `.gemini/`, `.github/`
- [x] Confirm `.agent/` remains explicitly experimental and excluded from default bootstrap behavior

## Execution

- [x] Add a dedicated onboarding/bootstrap script in the shared repo that operates from a downstream repository after `.github/openspec-shared` has been added
- [x] Implement submodule initialization/update behavior for `.github/openspec-shared` within the bootstrap flow
- [x] Implement default symlink creation for supported agent assets, `openspec/templates`, `openspec/config.yaml`, and `scripts/init-change.sh`
- [x] Implement copy-mode fallback for the same supported assets
- [x] Make bootstrap behavior idempotent and explicit about conflicting existing files
- [x] Rewrite [README.md](README.md) onboarding, supported-agents, and refresh sections to match the bootstrap flow
- [x] Review for duplication and unnecessary complexity
- [x] Confirm acceptance criteria are covered

Suggested start-of-work commands: `git checkout <default-branch>` -> `git pull --ff-only` -> `git checkout -b feat/multi-agent-onboarding` -> `git push -u origin feat/multi-agent-onboarding`

## Validation

- [x] Run the bootstrap flow in a clean fixture repo using default symlink mode
- [x] Re-run the bootstrap flow in the same fixture repo and confirm the layout remains correct
- [x] Run the bootstrap flow in a clean fixture repo using copy mode
- [x] Verify `.agent/` is not linked or documented as part of the default supported flow
- [x] Manually verify [README.md](README.md) matches the implemented commands and file layout
- [x] Run unit/integration tests if any are added for the bootstrap script
- [x] Run build or lint steps required by the repo, if applicable
- [x] Run security/code quality checks required by project standards
- [x] All completed tasks marked as complete
- [x] All steps in [Remote push validation]

## Remote push validation

Verification requirements (all must pass before PR or pushing updates to a PR):

- **Bootstrap validation** — run the documented onboarding flow in fixture repos; symlink mode and copy mode must both produce the expected layout
- **Regression validation** — rerun bootstrap in an already-wired repo; output must remain correct and non-destructive
- **Docs validation** — README commands and paths must match the implemented script behavior exactly
- **Build / lint** — run any repo-standard checks that cover shell scripts and Markdown if available
- if **ANY** of the above fail, you **MUST** iterate and address the failure

Use the project's documented commands for each of the above (see project README or agent instructions).

## PR and Merge

- [x] Run the required pre-PR self-review from `skills/openspec-apply-change/SKILL.md` before committing
- [x] Commit all changes to the working branch and push to remote
- [x] Open PR from working branch to `<default-branch>`
- [x] Wait for 120 seconds for the Agentic reviewers to post their comments
- [x] **Monitor PR comments** — when comments appear, address them, commit fixes, follow all steps in [Remote push validation] then push to the same working branch; repeat until no unresolved comments remain
- [x] Enable auto-merge once no blocking review comments remain
- [x] **Monitor CI checks** — when any CI check fails, diagnose and fix the failure, commit fixes, follow all steps in [Remote push validation] then push to the same working branch; repeat until all checks pass
- [x] Wait for the PR to merge — **never force-merge**; if a human force-merges, continue to Post-Merge

Ownership metadata:

- Implementer: agent
- Reviewer(s): human maintainer plus automated repo reviewers
- Required approvals: explicit human approval before merge

Blocking resolution flow:

- CI failure -> fix -> commit -> validate locally -> push -> re-run checks
- Security finding -> remediate -> commit -> validate locally -> push -> re-scan
- Review comment -> address -> commit -> validate locally -> push -> confirm resolved

## Post-Merge

- [x] `git checkout <default-branch>` and `git pull --ff-only`
- [x] Verify the merged changes appear on the default branch
- [x] Mark all remaining tasks as complete (`- [x]`)
- [x] Update repository documentation impacted by the change
- [x] Sync approved spec deltas into `openspec/specs/` (global spec)
- [x] Archive the change: move `openspec/changes/add-multi-agent-onboarding/` to `openspec/changes/archive/YYYY-MM-DD-add-multi-agent-onboarding/` **and stage both the new location and the deletion of the old location in a single commit** — do not commit the copy and delete separately
- [x] Confirm `openspec/changes/archive/YYYY-MM-DD-add-multi-agent-onboarding/` exists and `openspec/changes/add-multi-agent-onboarding/` is gone
- [x] Commit and push the archive to the default branch in one commit
- [x] Prune merged local feature branches: `git fetch --prune` and `git branch -d feat/multi-agent-onboarding`

Required cleanup after archive: `git fetch --prune` and `git branch -d feat/multi-agent-onboarding`
