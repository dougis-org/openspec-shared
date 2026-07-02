## GitHub Issues

- **Ticket:** n/a — No tracking ticket exists for this work.

## Why

The `sdd-with-feedback-loop` schema has no lifecycle hooks into GitHub Issues or GitHub Projects, so ticket status drifts silently as work progresses, and there is no enforced PR review before auto-merge is enabled — a reviewer sub-agent may or may not comment, but nothing guarantees a review happened before the PR is allowed to merge.

## Problem Space

The `sdd-with-feedback-loop` schema encodes the implementation lifecycle in three files (`config.yaml`, `schema.yaml`, `templates/tasks.md`) but none of them connect to GitHub Issues or GitHub Projects. As a result, issue status drifts silently — a ticket stays "Open" while a feature branch exists and a PR is under review. Additionally, the auto-merge step fires immediately on PR open with no guarantee that a code review has been performed; any review findings arrive after the merge is already queued.

## Scope

**In scope:**
- GitHub issue label transitions at branch creation (`in-progress`), PR open (`in-review`), and merge (auto-close via `Closes #N`)
- GitHub Projects board item transitions alongside label changes, using runtime-discovered field option IDs
- Preflight verification that `pr-review-toolkit:review-pr` is installed before implementation starts
- Enforced review gate: auto-merge only after `pr-review-toolkit:review-pr` returns zero findings
- Auto-detection of in-progress issues in `get-next-project-issue` using project board status and labels

**Out of scope:**
- Non-GitHub trackers (Linear, Azure DevOps)
- Bidirectional sync between board state and OpenSpec artifacts
- Expanding `get-next-project-issue` beyond in-progress filtering

## What Changes

- Add **GitHub issue lifecycle hooks** at three points: branch creation (mark in-progress), PR open (mark in-review + link PR to issue), and merge (auto-close via `Closes #N`).
- Add **GitHub Projects Kanban integration**: at each lifecycle point, move the linked project item through the board's status column (In Progress → In Review → Done) using runtime-discovered field option IDs.
- Add **enforced PR-review gate**: after opening a PR, run `pr-review-toolkit:review-pr` as a sub-agent and require all findings to be addressed before enabling auto-merge. Auto-merge is no longer enabled immediately on PR open.
- Add **preflight validation**: at the start of apply, verify `pr-review-toolkit:review-pr` is available; prompt the user to install it if missing and halt until confirmed.
- Update **`get-next-project-issue` skill**: auto-detect in-progress issues from the GitHub Projects board status and issue labels instead of asking the user manually; filter those issues out of the "next to work on" candidates automatically.
- **Remove** the `Closes #N` requirement from the "PR body if issue-driven" conditional — it becomes unconditional for issue-driven changes.

## Capabilities

### New Capabilities

- `github-issue-lifecycle`: The three-point lifecycle hooks (branch creation, PR open, merge) that update GitHub issue labels (`in-progress`, `in-review`) and move the linked GitHub Projects item through status columns via `gh project item-edit`. Includes runtime discovery of the project, status field, and option IDs.
- `enforced-pr-review-gate`: Preflight validation that `pr-review-toolkit:review-pr` is installed, the post-PR-open review performed via a sub-agent, the requirement that all findings are addressed before auto-merge is enabled, and the re-sequencing of auto-merge to occur only after the gate passes.

### Modified Capabilities

- `get-next-project-issue` skill: Auto-detection of in-progress issues from GitHub Projects board status and `in-progress` label, replacing the manual user question at Step 5.

## Impact

- **Schema instructions:** `schemas/sdd-with-feedback-loop/schema.yaml` — tasks artifact instruction updated.
- **Schema rules:** `config.yaml` — tasks rules updated to encode the lifecycle hooks, the review gate, and the preflight check.
- **Schema template:** `schemas/sdd-with-feedback-loop/templates/tasks.md` — Execution Step 2, PR and Merge section updated.
- **Skill:** `skills/get-next-project-issue/SKILL.md` — Steps 4, 5 updated.
- **External systems:** GitHub Issues API, GitHub Projects API (via `gh` CLI), `pr-review-toolkit:review-pr` plugin as a runtime dependency.

## Risks

- **Project column name variance:** Status column option names differ across projects. Mitigated by runtime discovery + semantic match (find the option whose name contains "in progress", "in review", "done") with a warn-and-skip fallback if no match is found.
- **No linked issue:** Changes that aren't issue-driven must skip lifecycle hooks gracefully. The template and rules gate all hooks on `if issue-driven`.
- **Plugin availability:** `pr-review-toolkit:review-pr` may not be installed. Mitigated by the preflight check at apply start.
- **Review loop non-convergence:** If findings never reach zero, auto-merge is permanently blocked. Mitigated by the existing blocking-resolution flow; a human can intervene and the agent reports the stall.

## Open Questions

_None — all decisions made during exploration._

## Non-Goals

- Linear or Azure DevOps integration.
- Bidirectional sync between GitHub Projects and OpenSpec artifacts.
- Reworking `get-next-project-issue` into a full backlog planner — only the in-progress filter is in scope.
- Supporting GitHub Projects columns beyond In Progress / In Review / Done.

## Change Control

If scope changes after approval, `proposal.md`, `design.md`, `specs/**/*.md`, and `tasks.md` must be updated before implementation starts.
