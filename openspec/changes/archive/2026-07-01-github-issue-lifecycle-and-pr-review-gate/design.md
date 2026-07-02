## Context

The `sdd-with-feedback-loop` schema encodes the implementation lifecycle in three places: `config.yaml` (rules applied by the agent), `schemas/sdd-with-feedback-loop/schema.yaml` (per-artifact instructions), and `schemas/sdd-with-feedback-loop/templates/tasks.md` (the generated task checklist). Changes to workflow behavior must be propagated consistently across all three, plus the `get-next-project-issue` skill which is the entry point for discovering what to work on next.

Currently the tasks template enables auto-merge immediately on PR open with no guaranteed review, and has no hooks into GitHub Issues or GitHub Projects.

## Goals / Non-Goals

**Goals:**
- Add three-point GitHub issue + project lifecycle hooks (branch creation, PR open, merge)
- Enforce a full `pr-review-toolkit:review-pr` review before auto-merge is enabled
- Add a preflight check for the review plugin at apply start
- Update `get-next-project-issue` to auto-detect in-progress items from the project board

**Non-Goals:**
- Linear, Azure DevOps, or any other tracker
- Bidirectional sync between board state and OpenSpec artifacts
- Changes to the pre-commit `openspec-review-code` review

## Decisions

### D1: Runtime discovery of GitHub Projects field option IDs

GitHub Projects status columns are project-specific (names like "In Progress", "Todo", "Done" are set per-project). Hardcoding these would break on any project with different names.

**Decision:** Discover field option IDs at runtime using `gh project field-list` and match semantically — find the option whose lowercase name contains "in progress", "in review" (or "review"), and "done". Warn and skip the project-item update (but not the issue label update) if no match is found.

**Alternative considered:** Require a configuration file mapping option names. Rejected — adds setup friction for every new repo; runtime discovery works.

### D2: Issue label strategy

GitHub has no native status field on issues. Labels are the standard convention.

**Decision:** Use labels `in-progress` and `in-review` on the issue directly, in addition to the project board moves. This makes status visible on the issue list even for users not looking at the project board.

**Lifecycle:**
- Branch created → add `in-progress`
- PR opened → add `in-review`, remove `in-progress`
- Merged → issue auto-closes via `Closes #N` in PR body; GitHub Projects auto-moves closed issues to Done in most configurations

### D3: Preflight validation placement

The review plugin check needs to run before any implementation work begins.

**Decision:** Add a Preflight section to the tasks template, placed between Preparation and Execution. The agent verifies `pr-review-toolkit:review-pr` is callable (by checking the available skills list or attempting a dry run); if not, it prompts the user to install it and halts until confirmed.

### D4: PR review gate sequencing

Current flow: open PR → immediately enable auto-merge → react to whatever review comments appear.

**Decision:** New flow: open PR → wait 60 seconds for CI to start → run `pr-review-toolkit:review-pr` sub-agent → address all findings → THEN enable auto-merge → continue monitoring loop. Auto-merge is never enabled before the initial review pass completes.

**Why 60s wait before review:** Give CI checks time to start so the reviewer has real check status to consider.

### D5: `get-next-project-issue` in-progress detection

Current Step 5 asks the user manually. With lifecycle hooks in place, the project board is authoritative.

**Decision:** Replace Step 5's manual question with automatic detection:
1. Fetch project items via `gh project item-list`
2. Mark any item in an "In Progress" or "In Review" equivalent column as `IN PROGRESS`
3. Also mark issues with the `in-progress` or `in-review` label as `IN PROGRESS`
4. Existing open-PR detection (Step 5's gh pr list check) is kept as a third signal

The manual question becomes a fallback only if the project API call fails.

### D6: Encoding in both config.yaml rules and schema.yaml instruction

Rules in `config.yaml` guide the agent when writing the `tasks.md` artifact. Instructions in `schema.yaml` guide the agent when executing tasks. Both must reflect the new lifecycle and gate. The template `tasks.md` provides the concrete checklist that the agent fills in. All three must stay consistent.

## Risks / Trade-offs

- **No linked issue:** Tasks template and rules gate all hooks on "if this change is issue-driven". If no issue number is present, lifecycle hooks are silently skipped. Risk: change proceeds without any tracking. Mitigated by the existing `GitHub Issues` section in `proposal.md` — the proposal explicitly captures whether an issue exists.
- **Project item not in project:** An issue may exist but not be added to any GitHub Project. `gh project item-list` will return no matching item. Mitigated by warn-and-skip: issue label update still proceeds, project move is skipped with a warning.
- **Review loop non-convergence:** If `pr-review-toolkit:review-pr` always finds new findings (e.g., due to a flaky rule), auto-merge is permanently blocked. Mitigated by the human as final arbiter — the blocking-resolution flow already covers this; the agent reports the stall and the user can intervene.
- **`gh` CLI scope:** `gh project item-edit` requires the `project` OAuth scope. If the token lacks it, the command fails. Mitigated by a clear error message instructing the user to run `gh auth refresh -s project`.
