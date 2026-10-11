---
name: get-next-project-issue
description: Find the next logical unblocked GitHub issue to work on for a tracked project. Syncs to main, discovers project docs, evaluates current issue states against GitHub, updates the docs on a branch, cuts a doc PR set to auto-merge, monitors it to completion, then presents the next issue to action.
license: MIT
metadata:
  author: ai-agent-setup
  version: "1.1"
---

# Get Next Project Issue

Discover and surface the next logical, unblocked GitHub issue to work on across
any project tracked in the `docs/` folder. Along the way, keep the project docs
fresh by updating them to reflect current GitHub issue status and committing
those updates through a PR.

---

## Steps

### Step 1 — Sync to main

Switch to `main` and pull the latest from remote so you are working from a
clean, up-to-date baseline:

```bash
git checkout main
git pull --rebase
```

If there are local uncommitted changes, warn the user and ask whether to stash
them before continuing. Do not proceed with a dirty working tree.

---

### Step 2 — Discover project doc folders

Scan the `docs/` directory (recursively) to find folders that look like tracked
project roadmaps. A folder qualifies if it contains a `README.md` that mentions
GitHub issue numbers (pattern: `#\d+` or `github.com/.*/issues/\d+`).

Run the scan efficiently using a single command, for example:

```bash
find docs/ -name "README.md" -print0 | xargs -0 grep -E -l "issues/|#[0-9]+" 2>/dev/null
```

`-print0` / `-0` handles directory or file names containing spaces correctly.
The `-E` pattern matches both full GitHub issue URLs (`issues/123`) and
shorthand references (`#123`).

Also check one level up for a potential `docs/projects/` grouping pattern in
case projects are nested under an intermediate parent directory.

Collect every qualifying folder path.

---

### Step 3 — Ask the user to select a project

Present the list of discovered project folders to the user and ask them to
select one. Use whatever mechanism the agent runtime provides for interactive
selection (e.g., a tool call, a numbered list in a message, or a follow-up
prompt). Wait for the user's response before proceeding.

- Label each option by its folder name (and the title from its `README.md` if
  easy to extract, e.g. the first `# Heading`).
- Include an option for "All / scan all projects" if more than one exists.
- Wait for the user's selection before proceeding.

---

### Step 4 — Evaluate current project state

For the selected project folder:

1. **Read all markdown files** in that folder (README + per-phase / per-section
   docs) to build a complete picture of the project structure, phases,
   sub-issues, dependencies, and any status already captured in the docs.

2. **Extract every GitHub issue number** referenced across all those files.
   Deduplicate the list.

3. **Fetch the current state of every issue** from GitHub in a single API
   call, then filter locally to the issue numbers extracted from the docs:

   ```bash
   gh issue list --repo <owner>/<repo> --limit 1000 \
     --json number,title,state,labels
   ```

   Filter the returned JSON to only the numbers extracted in step 2.
   Record `number`, `title`, `state` (`OPEN` / `CLOSED`), and `labels` for each.
   Using a single list call avoids the rate-limiting and process-spawn
   overhead that comes from running one `gh issue view` per issue.

4. **Fetch project item status for every open issue** from the GitHub Projects
   board. First discover the project number:

   ```bash
   gh project list --owner <owner> --format json
   ```

   Then fetch all items with their current status column value:

   ```bash
   gh project item-list <project-number> --owner <owner> --format json
   ```

   Record the status column value for each item (match on `content.number`
   to correlate with issue numbers). If this call fails (e.g., token lacks
   `project` scope or no project exists), note the failure and continue —
   in-progress detection will fall back to labels and open-PR signals only.

5. **Determine completion status** for each phase / section:
   - All sub-issues CLOSED → phase complete
   - Some CLOSED, some OPEN → phase in progress
   - All OPEN → phase not started
   - Note any issue whose dependencies (as described in the docs) are now fully
     met (i.e., all blocking predecessors are CLOSED).

---

### Step 5 — Detect in-flight work automatically

Mark an open issue as `IN PROGRESS` if **any** of the following signals is true:

1. **GitHub Projects board** (from Step 4): the issue's project item is in a
   status column whose name semantically matches "In Progress" or "In Review"
   (case-insensitive substring match). This is the primary signal when project
   data is available.

2. **Issue labels**: the issue carries the label `in-progress` or `in-review`
   (from the `labels` field fetched in Step 4). This provides a redundant
   signal visible on the issue list even without the project board.

3. **Open PR**: check whether an open PR exists that references the issue:

   ```bash
   gh pr list --repo <owner>/<repo> --state open \
     --json number,title,headRefName,body 2>/dev/null
   ```

   Match PRs to issues by body text (`Closes #N`, `Fixes #N`) or branch name
   conventions. Mark any matched issue as `IN PROGRESS`.

If the `gh project item-list` call from Step 4 failed and no label signal is
present, fall back to asking the user manually:

> Are any of the open issues currently being worked on (e.g., on a feature
> branch or open PR)? If yes, which issue numbers?

Accept a free-text response (comma-separated numbers, "none", or issue URLs)
and mark each reported issue as `IN PROGRESS`.

---

### Step 6 — Create a documentation update branch

Create and switch to a new branch named:

```
doc/status-update-<project-folder>-<YYYY-MM-DD>
```

For example: `doc/status-update-multi-user-campaigns-2026-06-07`

```bash
git checkout -b doc/status-update-<project-folder>-$(date +%Y-%m-%d)
```

---

### Step 7 — Update project documents

Apply the following documentation update pattern consistently across all project docs:

**README.md updates:**
- Update the `> Status:` header line with today's date and an accurate
  in-progress summary (e.g., "Phase 1 ✅ complete · Phase 2 🔄 in progress").
- In the phase roadmap table, add or refresh a **Status** column:
  - ✅ `**Complete**` — all sub-issues CLOSED
  - 🔄 `**N/M done**` — some CLOSED
  - 🟡 `Not started` — all OPEN
  - 🚧 `**In progress**` — has an open PR
- Ensure every issue number in the table is a clickable GitHub link.
- Update the wave / build-order table: strike through completed waves with
  `~~text~~`; update notes to reflect what's done and what's unblocked next.

**Per-phase / per-section doc updates:**
- Update the phase title to append `✅ COMPLETE` when the epic + all
  sub-issues are closed.
- Append `(partially complete)` or `(in progress)` when partially done.
- Update each sub-issue heading to prepend:
  - `✅` and append `— CLOSED` for closed issues
  - `🚧` and append `— IN PROGRESS` for issues with an open PR
  - `🟡` and append `— OPEN` for untouched open issues
- Update **Depends on:** lines to annotate which dependencies are now met
  (e.g., "✅ Phase 1 complete").
- Update the epic tracking blockquote to show `— CLOSED ✅` or `— OPEN` and
  add a **Status:** line summarising the phase's current state.

Do not alter any design content, diagrams, acceptance criteria, or wording
that is not status-related. Preserve all existing prose and structure.

---

### Step 8 — Commit and open a documentation PR

Commit all changed doc files with a clear message:

```
docs(<project-folder>): update status to reflect closed issues

- <Phase N> fully complete: #<epic> + all sub-issues (#X–#Y) closed
- <Phase M> partial: <done items> closed; <open items> still open
- ...
- All GitHub issue links verified and present
```

Push the branch and open a PR:

```bash
gh pr create \
  --title "docs(<project>): sync status with GitHub issue states (<date>)" \
  --body "Automated documentation status sync.

Updates issue status markers (✅/🔄/🟡), refreshes the Status column in the
phase roadmap table, and updates per-phase doc headings to reflect current
GitHub issue states.

All changes are doc-only (no code)." \
  --base main \
  --label documentation
```

After the PR is created, enable auto-merge with squash via a separate command:

```bash
gh pr merge <pr-number> --auto --squash
```

If auto-merge cannot be enabled (e.g., the repository's branch protection
requires a human review before merge is allowed), note this to the user and
proceed to Step 9 — the PR will merge once approved.

---

### Step 9 — Monitor the PR to merge

Invoke the **pr-reviewer** skill on the newly created PR.

Pass it the PR number or URL. The pr-reviewer skill will:
- Analyse any failing checks
- Resolve comment threads
- Ensure the PR reaches a mergeable state

Poll the PR state every 30 seconds (up to 10 minutes) until it is merged or
requires human intervention:

```bash
gh pr view <number> --repo <owner>/<repo> --json state,mergeStateStatus
```

- If merged → proceed to Step 10.
- If blocked on a required review → inform the user and proceed to Step 10
  anyway (the docs will merge when approved).
- If failed checks are non-doc-related → note and proceed.

---

### Step 10 — Present the next issue to work on

Using the evaluation from Step 4 (and in-flight context from Step 5), identify
the **next most logical unblocked issue**:

**Selection algorithm:**

1. Filter to issues that are `OPEN` and **not** `IN PROGRESS`.
2. Filter to issues whose dependencies (as described in the docs) are fully
   met — i.e., every issue they depend on is `CLOSED`.
3. Among unblocked issues, prefer:
   - Issues in the **earliest incomplete phase** (lower phase number first)
   - Within a phase, prefer issues with no remaining sub-dependencies over
     those that block others
   - Issues explicitly flagged `(next up)` in the docs
4. If multiple issues tie, present all of them (they can run in parallel).

**Output format:**

```
## 🎯 Next Issue to Work On

**Issue:** [#NNN — Title](https://github.com/<owner>/<repo>/issues/NNN)
**Phase:** Phase N — <phase name>
**Why unblocked:** <brief explanation of which dependencies are satisfied>

### Acceptance criteria (from the docs)
<paste the acceptance criteria block from the phase doc>

### To start working on this:
- Use `/opsx-explore #NNN` to explore the problem space
- Use `/opsx-propose` to create a change proposal
- Or assign and branch directly: `gh issue assign NNN --me && git checkout -b feat/...`
```

If multiple issues are equally unblocked and can run in parallel, list them all
with a note that they can be worked concurrently.

If no issue is unblocked (everything open is blocked on incomplete work),
present the **bottleneck issue** — the single issue whose completion would
unblock the most downstream work — and explain why it's the critical path item.

---

## Guardrails

- **Never commit code changes** — this skill touches only doc files.
- **Never rewrite design content** — only update status markers and links.
- **Always confirm the branch is created before editing files** — do not edit
  on `main`.
- **Do not auto-merge if the PR has failing code checks** — report and let the
  user decide.
- **Respect in-flight work** — do not recommend an issue already assigned or
  with an open PR unless it's the only unblocked option.
- **Keep status emoji consistent** — use exactly four states and no others:
  - ✅ — all sub-issues CLOSED (phase/item complete)
  - 🔄 — mix of CLOSED and OPEN sub-issues (partial progress, no open PR)
  - 🚧 — an open PR exists for this issue (actively being worked)
  - 🟡 — all sub-issues OPEN, no PR (not yet started)
- **Idempotent updates** — if a status marker already matches reality (e.g.
  already shows ✅ and the issue is CLOSED), leave it unchanged.
