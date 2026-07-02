## 1. Preparation

- [x] 1.1 Checkout `main` and pull fast-forward-only: `git checkout main && git pull --ff-only`
- [x] 1.2 Create working branch: `git checkout -b feat/github-issue-lifecycle-and-pr-review-gate`
- [x] 1.3 Push working branch to remote: `git push -u origin feat/github-issue-lifecycle-and-pr-review-gate`

## 2. Preflight Check — Verify Plugin

- [x] 2.1 Confirm `pr-review-toolkit:review-pr` appears in the available skills list; if absent, halt and prompt user to install before continuing

## 3. Update `config.yaml` — Tasks Rules

- [x] 3.1 Remove the rule requiring `"GitHub Issues"` as a required proposal section (the template already has this section; the rule becomes redundant and will be replaced by the tracker-update rules below)
- [x] 3.2 Add rule: at working branch creation, if change is issue-driven, run `gh issue edit #N --add-label "in-progress"` and move the GitHub Project item to the "In Progress" status column via runtime-discovered field option IDs
- [x] 3.3 Add rule: when opening the PR, if issue-driven, run `gh issue edit #N --add-label "in-review" --remove-label "in-progress"`, move the project item to the "In Review" column, and include `Closes #N` in the PR body unconditionally (not as an "if issue-driven" conditional on the existing `Closes #N` language)
- [x] 3.4 Replace the existing auto-merge-immediately rule with: after opening the PR, wait 60 seconds, then spawn a sub-agent to run `pr-review-toolkit:review-pr`; address all findings (commit, push, re-run) until zero findings remain; only then enable `gh pr merge <PR-URL> --auto --merge`
- [x] 3.5 Add rule: add a Preflight section to the generated tasks.md (between Preparation and Execution) that verifies `pr-review-toolkit:review-pr` is installed; halt if not

## 4. Update `schemas/sdd-with-feedback-loop/schema.yaml` — Tasks Instruction

- [x] 4.1 Sync the `tasks` artifact instruction with the rule changes in 3.2–3.5 so schema.yaml and config.yaml describe identical behavior (both are authoritative encoding sites)

## 5. Update `schemas/sdd-with-feedback-loop/templates/tasks.md` — Template

- [x] 5.1 Add a **Preflight** section between Preparation and Execution:
  - Checkbox: verify `pr-review-toolkit:review-pr` is available; halt and prompt if not
- [x] 5.2 In the **Execution** section, after Step 2 (create and push working branch), add:
  - Checkbox: if issue-driven — `gh issue edit #N --add-label "in-progress"`
  - Checkbox: if issue-driven — discover project, field, and option IDs; run `gh project item-edit` to move item to "In Progress" (warn and skip if not found or token lacks project scope)
- [x] 5.3 In the **PR and Merge** section, replace the immediate auto-merge step with the gated sequence:
  - Open PR (with `Closes #N` in body if issue-driven)
  - If issue-driven: `gh issue edit #N --add-label "in-review" --remove-label "in-progress"` and move project item to "In Review" column
  - Wait 60 seconds for CI to start
  - Spawn sub-agent: run `pr-review-toolkit:review-pr`
  - Address all findings; commit, push; repeat until zero findings
  - Enable auto-merge: `gh pr merge <PR-URL> --auto --merge`
  - Continue monitoring loop (address comments and CI failures until MERGED)
- [x] 5.4 Verify the Ownership metadata and Blocking resolution flow sections are still present and unchanged

## 6. Update `skills/get-next-project-issue/SKILL.md`

- [x] 6.1 In **Step 4**, add after the `gh issue list` fetch: fetch project items via `gh project item-list <project-number> --owner <owner> --format json` and record each item's current status column value
- [x] 6.2 In **Step 5**, replace the manual "Are any issues being worked on?" question with automatic detection:
  - Mark an issue `IN PROGRESS` if its project item is in a column semantically matching "In Progress" or "In Review"
  - Mark an issue `IN PROGRESS` if it carries the `in-progress` or `in-review` label
  - Keep existing open-PR detection as a third signal
  - Fall back to the manual question only if the `gh project item-list` call fails
- [x] 6.3 Verify **Step 10** selection algorithm still correctly filters `IN PROGRESS` items (no change expected — the filter logic is already correct; only the detection source changes)

## 7. Validation

- [x] 7.1 Read all three encoding sites (`config.yaml`, `schemas/sdd-with-feedback-loop/schema.yaml`, `schemas/sdd-with-feedback-loop/templates/tasks.md`) and confirm they describe consistent behavior for the lifecycle hooks and review gate
- [x] 7.2 Read `skills/get-next-project-issue/SKILL.md` and confirm Steps 4 and 5 correctly describe automatic in-progress detection with the manual question as fallback
- [x] 7.3 Verify no references to Linear, Azure DevOps, or the old `tracker-lifecycle-integration` capability exist in any modified file
- [x] 7.4 Confirm `templates/proposal.md` is unchanged (GitHub Issues section still present)

## 8. PR and Merge

- [x] 8.1 Before commit: spawn sub-agent to run `openspec-review-code`; apply all clearly-correct findings; re-validate
- [x] 8.2 Commit all changes: `git add -A && git commit -m "feat: github issue lifecycle hooks and enforced pr review gate"`
- [x] 8.3 Push to remote: `git push`
- [x] 8.4 Open PR to `main`; include `Closes #N` if an issue was tracked for this change
- [x] 8.5 Wait 60 seconds; run `pr-review-toolkit:review-pr`; address findings; enable auto-merge once zero findings
- [x] 8.6 Monitor until merged: address new comments and CI failures; push fixes; repeat until `gh pr view --json state` returns `MERGED`

## 9. Post-Merge

- [x] 9.1 `git checkout main && git pull --ff-only`
- [x] 9.2 Verify merged changes appear on `main`
- [x] 9.3 Sync approved spec deltas to `openspec/specs/`:
  - Copy `openspec/changes/github-issue-lifecycle-and-pr-review-gate/specs/github-issue-lifecycle/spec.md` → `openspec/specs/github-issue-lifecycle/spec.md`
  - Copy `openspec/changes/github-issue-lifecycle-and-pr-review-gate/specs/enforced-pr-review-gate/spec.md` → `openspec/specs/enforced-pr-review-gate/spec.md`
  - Update any relative links in copied specs to point to archive location
- [x] 9.4 Archive: move `openspec/changes/github-issue-lifecycle-and-pr-review-gate/` to `openspec/changes/archive/2026-07-01-github-issue-lifecycle-and-pr-review-gate/` in a single atomic commit (stage both the new location and the deletion of the original)
- [ ] 9.5 Create doc branch, open archive PR, enable auto-merge, monitor until merged
- [ ] 9.6 Prune merged local branches: `git fetch --prune && git branch -D feat/github-issue-lifecycle-and-pr-review-gate`

---

Ownership metadata:

- Implementer:
- Reviewer(s):
- Required approvals: 1

Blocking resolution flow:

- CI failure → fix → commit → validate → push → re-run checks
- Review finding → address → commit → validate → push → re-run `pr-review-toolkit:review-pr`
- Project scope change → update proposal.md, design.md, specs, and tasks.md before continuing
