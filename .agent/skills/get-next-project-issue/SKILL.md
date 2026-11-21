---
name: get-next-project-issue
description: Find the next logical unblocked GitHub issue to work on for a tracked project. Syncs to main, discovers project docs, evaluates current issue states against GitHub, updates the docs on a branch only if statuses changed, cuts a doc PR set to auto-merge, monitors it to completion, then presents the next issue to action.
license: MIT
metadata:
  author: ai-agent-setup
  version: "1.2"
---

# Get Next Project Issue

Surface the next logical, unblocked GitHub issue to work on across any project tracked in `docs/`. Along the way, keep the project docs fresh by updating status markers and merging those updates through a PR (only when something actually changed).

## Steps

### Step 1 — Sync to main

```bash
git checkout main
git pull --rebase
```

If the working tree is dirty, warn the user and ask whether to stash. Do not proceed with a dirty tree.

### Step 2 — Discover project doc folders

A folder qualifies if it contains a `README.md` mentioning GitHub issue numbers (`#\d+` or `github.com/.*/issues/\d+`):

```bash
find docs/ -name "README.md" -print0 | xargs -0 grep -E -l "issues/|#[0-9]+" 2>/dev/null
```

Include `docs/projects/`-style nesting. Collect every qualifying folder.

### Step 3 — Select a project

If more than one folder qualifies, ask the user to pick one (label by folder name and the README's first `# Heading`; include "All projects"). With exactly one, use it and say so. Wait for the answer before continuing.

### Step 4 — Evaluate current project state

For the selected project:

1. **Read `README.md`** (roadmap, phase and wave tables, dependencies, current status markers). Read per-phase docs in full only for phases not marked complete in the README and for the phase of the issue you will present (for its acceptance criteria). For phases the README marks complete, do not read them in full but still collect their issue numbers with `grep -ohE "#[0-9]+|issues/[0-9]+" <phase-doc>` so reopened sub-issues are detected; if any such issue is now `OPEN`, read that phase doc in full.

2. **Extract and dedupe every issue number** from the README, the docs you read, and the greps above.

3. **Fetch only those issues** with aliased GraphQL calls, not the repository's whole issue list. Split the numbers into chunks of at most 100, run one call per chunk (`i<N>: issue(number:<N>) { number title state }` per alias), and merge the results:

   ```bash
   gh api graphql -f query='{ repository(owner:"<o>", name:"<r>") { i101: issue(number:101) { number title state } i102: issue(number:102) { number title state } } }'
   ```

   Record `number`, `title`, and `state` for each. In-flight labels are fetched exactly in Step 5 (a per-issue label list could be truncated).

4. **Fetch project board status** for the open issues, trimming output to what you need:

   ```bash
   gh project list --owner <owner> --format json --jq '.projects[] | {number,title}'
   gh project item-list <project-number> --owner <owner> --format json --jq '.items[] | {n:.content.number, status}'
   ```

   If this fails (no `project` scope or no project), note it and continue; in-flight detection falls back to labels and open PRs.

5. **Phase status:** all sub-issues CLOSED → complete; mixed → in progress; all OPEN → not started. Note issues whose dependencies (per the docs) are now all CLOSED.

### Step 5 — Detect in-flight work

Mark an open issue `IN PROGRESS` if any signal holds:

1. Its project item is in a status column matching "In Progress" or "In Review" (case-insensitive substring); primary signal when available.
2. It carries the label `in-progress` or `in-review`. Fetch these exactly, so no label can be truncated:

   ```bash
   gh issue list --repo <owner>/<repo> --state open --label in-progress --limit 500 --json number --jq '[.[].number]'
   gh issue list --repo <owner>/<repo> --state open --label in-review --limit 500 --json number --jq '[.[].number]'
   ```

3. An open PR references it:

   ```bash
   gh pr list --repo <owner>/<repo> --state open --limit 200 --json number,headRefName,body \
     --jq '.[] | {number, headRefName, closes: [.body | scan("(?i)(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?\s+(?:https://github\.com/[^/]+/[^/]+/issues/|[\w.-]+/[\w.-]+#|#)[0-9]+")]}'
   ```

   This matches closing keywords with or without a colon, and `#N`, `owner/repo#N`, and full issue URLs. Also match by branch-name convention.

If the board call failed and no label signal exists, ask the user once which open issues are in flight (comma-separated numbers, "none", or URLs).

### Step 6 — Decide whether docs need updating

Compare **every** status-related element in the docs with Step 4–5 reality, not just emoji: the README `> Status:` line, the roadmap Status column, phase title and sub-issue heading markers, `Depends on:` annotations, epic Status lines, and wave/build-order strikethroughs and notes. Skip Steps 7–9 (no branch, no PR) and go to Step 10 only if **all** of them already match. Updates are idempotent.

### Step 7 — Branch and update docs

```bash
git checkout -b doc/status-update-<project-folder>-$(date +%Y-%m-%d)
```

Never edit on `main`. Then update only status-related content:

- **README.md:** the `> Status:` line (today's date, short in-progress summary); a **Status** column in the phase roadmap table (✅ `**Complete**`, 🔄 `**N/M done**`, 🟡 `Not started`, 🚧 `**In progress**`); every issue number a clickable GitHub link; in the wave/build-order table, strike through completed waves with `~~text~~` and update notes on what is done and unblocked next.
- **Per-phase docs:** append `✅ COMPLETE` to the phase title when the epic and all sub-issues are closed (`(partially complete)` / `(in progress)` otherwise); prefix each sub-issue heading with ✅ (append `— CLOSED`), 🚧 (append `— IN PROGRESS`), or 🟡 (append `— OPEN`); annotate **Depends on:** lines with what is now met (e.g. "✅ Phase 1 complete"); show `— CLOSED ✅` or `— OPEN` on the epic tracking blockquote with a **Status:** summary line.

Do not alter design content, diagrams, acceptance criteria, or any non-status wording.

### Step 8 — Commit and open the doc PR

Commit with a message like `docs(<project-folder>): update status to reflect closed issues` plus one bullet per phase change. Push, then:

```bash
gh pr create --base main --label documentation \
  --title "docs(<project>): sync status with GitHub issue states (<date>)" \
  --body "Doc-only status sync: updates status markers, the roadmap Status column, and phase headings to match current GitHub issue states."
gh pr merge <pr-number> --auto --squash
```

If auto-merge cannot be enabled (e.g. branch protection needs a human review), tell the user and continue; the PR merges once approved.

### Step 9 — Drive the PR to merge

Invoke the **pr-reviewer** skill with the PR number. It is event-driven (`gh pr checks --watch`) and capped at two fix iterations; do not add a separate poll loop here.

- Merged → Step 10.
- Blocked on a required human review → tell the user and continue to Step 10 (the docs merge when approved).
- Failing checks unrelated to docs → note and continue.

### Step 10 — Present the next issue

From the Step 4 evaluation and Step 5 in-flight data:

1. Keep issues that are `OPEN` and not `IN PROGRESS`.
2. Keep those whose dependencies (per the docs) are all `CLOSED`.
3. Prefer the earliest incomplete phase; within a phase, issues with no remaining sub-dependencies over those that block others; issues flagged `(next up)` in the docs.
4. If several tie, present all (they can run in parallel).

If nothing is unblocked, present the **bottleneck issue**: the one whose completion unblocks the most downstream work, and why it is the critical path.

```
## 🎯 Next Issue to Work On

**Issue:** [#NNN — Title](https://github.com/<owner>/<repo>/issues/NNN)
**Phase:** Phase N — <phase name>
**Why unblocked:** <which dependencies are satisfied>

### Acceptance criteria (from the docs)
<acceptance criteria block from the phase doc>

### To start working on this:
- `/opsx-explore #NNN` to explore the problem space
- `/opsx-propose` to create a change proposal
- Or assign and branch directly: `gh issue assign NNN --me && git checkout -b feat/...`
```

## Guardrails

- Touch only doc files; never commit code. Never rewrite design content; only status markers and links.
- Confirm the doc branch exists before editing; never edit on `main`.
- Do not auto-merge a PR with failing code checks; report and let the user decide.
- Respect in-flight work: do not recommend an issue already assigned or with an open PR unless it is the only unblocked option.
- Use exactly four status emoji: ✅ all sub-issues CLOSED; 🔄 mix of CLOSED and OPEN, no open PR; 🚧 an open PR exists; 🟡 all OPEN, no PR.
- Idempotent: if a marker already matches reality, leave it unchanged.
