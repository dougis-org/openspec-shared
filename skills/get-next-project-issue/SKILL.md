---
name: get-next-project-issue
description: Find the next logical unblocked GitHub issue to work on for a tracked project. Syncs to main, discovers project docs, evaluates current issue states against GitHub, updates the docs on a branch, cuts a doc PR set to auto-merge, monitors it to completion, then presents the next issue to action.
license: MIT
metadata:
  author: session-combat
  version: "1.0"
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
find docs/ -name "README.md" | xargs grep -l "issues/" 2>/dev/null
```

Also check one level up for a potential `docs/projects/` grouping pattern in
case projects are nested under an intermediate parent directory.

Collect every qualifying folder path.

---

### Step 3 — Ask the user to select a project

Use the **AskUserQuestion tool** to present the list of discovered project
folders as options.

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

3. **Fetch the current state of every issue** from GitHub in a single batched
   pass. Use the GitHub CLI efficiently — fetch in parallel where possible:

   ```bash
   for n in <issue numbers>; do
     gh issue view $n --repo <owner>/<repo> \
       --json number,title,state,labels 2>/dev/null &
   done
   wait
   ```

   Record `number`, `title`, and `state` (`OPEN` / `CLOSED`) for each issue.

4. **Determine completion status** for each phase / section:
   - All sub-issues CLOSED → phase complete
   - Some CLOSED, some OPEN → phase in progress
   - All OPEN → phase not started
   - Note any issue whose dependencies (as described in the docs) are now fully
     met (i.e., all blocking predecessors are CLOSED).

---

### Step 5 — Ask about in-flight work

Use the **AskUserQuestion tool** to ask:

> Are any of the open issues currently being worked on (e.g., on a feature
> branch or open PR)? If yes, which issue numbers?

Accept a free-text response (comma-separated numbers, "none", or issue URLs).
For each reported in-flight issue, check whether an open PR exists:

```bash
gh pr list --repo <owner>/<repo> --state open \
  --json number,title,headRefName,body 2>/dev/null
```

Match PRs to issues by body text (`Closes #N`, `Fixes #N`) or branch name
conventions. Mark any matched issue as `IN PROGRESS` in your evaluation.

---

### Step 6 — Create a documentation update branch

Create and switch to a new branch named:

```
doc/status-update-<project-folder>-<YYYY-MM-DD>
```

For example: `doc/status-update-multi-user-campaigns-2026-06-07`

```bash
git checkout -b doc/status-update-<project>-<date>
```

---

### Step 7 — Update project documents

Apply the same documentation update pattern used in this session:

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
  --label documentation \
  --auto-merge \
  --squash
```

If `--auto-merge` is not supported (e.g., branch protection requires reviews),
note this and proceed to Step 9 regardless.

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
- **Keep status emoji consistent** — use only ✅ (done), 🔄 (in progress),
  🚧 (PR open), and 🟡 (not started) to avoid visual noise.
- **Idempotent updates** — if a status marker already matches reality (e.g.
  already shows ✅ and the issue is CLOSED), leave it unchanged.
