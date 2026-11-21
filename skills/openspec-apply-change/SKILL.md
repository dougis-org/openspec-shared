---
name: openspec-apply-change
description: Implement tasks from an OpenSpec change. Use when the user wants to start implementing, continue implementation, or work through tasks.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.1"
  generatedBy: "1.2.0"
---

# Apply Change

Implement tasks from an OpenSpec change, through to a merged PR. Archive is a separate stage (`/opsx:archive`).

## Input

Optional change name. If omitted, infer from context; auto-select if only one active change exists; otherwise run `openspec list --json` and ask the user. Announce `Using change: <name>` (override: `/opsx:apply <other>`).

## Steps

1. **Status and instructions**

   ```bash
   openspec status --change "<name>" --json
   openspec instructions apply --change "<name>" --json
   ```

   - `state: "blocked"` → show missing artifacts, suggest the propose skill.
   - `state: "all_done"` → suggest archive.
   - If the `tests` artifact is missing, create it from the tests template.

2. **Read context (minimal)**

   Read `tasks`, `tests`, and `specs` files from `contextFiles`. Read `proposal.md` and `design.md` only on first start of the change, when a task is ambiguous, or when extracting `## GitHub Issues` for the PR. Follow `contextFiles` as returned; do not assume file names.

3. **Branch**

   `git checkout <default-branch>`, `git pull --ff-only`, then `git checkout -b <feature-branch>` (or checkout if it exists) and `git push -u origin <feature-branch>` before any implementation.

4. **Implement tasks (strict BDD/TDD)**

   For each pending task, with one-line progress updates (`task N/M: <desc>`):

   1. Red: add the behavior-focused case to `tests.md`, write the test, run it, confirm it fails.
   2. Green: write the minimum code to pass; run tests.
   3. Refactor with tests green.
   4. Mark the task `- [x]` immediately.

   Pause (do not guess) if a task is unclear, implementation reveals a design issue (suggest artifact updates), an error or blocker occurs, or the user interrupts.

5. **Local validation (CI-equivalent)**

   Run the repo's own equivalents of its CI checks: tests, build, lint/static analysis, security checks, coverage requirements. Find commands and thresholds in the README / CLAUDE.md / AGENTS.md / CI config. All must pass before any push. Never lower thresholds or skip/disable checks to get green; if a gate looks wrong, pause and ask the user.

6. **Pre-commit review** *(before every commit)*

   Spawn a sub-agent to run `openspec-review-code`. Pass the SHA of the last reviewed commit if there is one (first review: none, so it diffs against the default branch). Fix all findings, re-run validation, then commit and record the new HEAD SHA as the last reviewed commit.

7. **Commit, push, open PR** *(all tasks done and validation green)*

   - Commit and push the working branch.
   - Extract `#N` / `owner/repo#N` references from `## GitHub Issues` in `proposal.md` (ignore list markers, blank lines, the HTML comment). If any exist, the PR body MUST end with a `Closes <ref>` line per reference.
   - Open the PR to the default branch, announce the URL, and **immediately** run `gh pr merge <PR-URL> --auto --merge` (never `--admin`, never force-merge).
   - Wait 3 minutes before the first check (CI start and early reviewer comments).

8. **PR loop** *(autonomous until merged; never wait for a human to report comments or merge)*

   Each iteration:

   a. **Cheap state check:** `gh pr view <PR-URL> --json state,mergeStateStatus,headRefOid`. `MERGED` → step 9. `CLOSED` → stop and notify the user; skip step 9. If nothing changed since the last iteration and checks are still pending, wait 3 minutes and repeat (no further queries).

   b. **One query for everything:**

      ```bash
      gh api graphql -f query='{ repository(owner:"<o>", name:"<r>") { pullRequest(number:<n>) { reviewThreads(first:100) { pageInfo { hasNextPage endCursor } nodes { id isResolved comments(last:1) { nodes { body author { login } } } } } commits(last:1) { nodes { commit { statusCheckRollup { contexts(first:100) { nodes { ... on CheckRun { name conclusion isRequired(pullRequestNumber:<n>) } ... on StatusContext { context state isRequired(pullRequestNumber:<n>) } } } } } } } } } }'
      ```

      Paginate threads only if `hasNextPage` is true. Consider only unresolved threads and failing **required** checks.

   c. **Fix everything in one pass:** for each failing required check read `gh run view <run-id> --log-failed`, diagnose, and fix in code (quality-gate and coverage failures are fixed in code, never waived); for each unresolved thread implement the change or reply politely if unclear/out of scope. Run local validation (step 5), run the pre-commit review (step 6, incremental), commit, push **once**, wait 3 minutes.

   d. **Resolve leftovers:** re-query threads; resolve any addressed thread still open in one call, using one aliased mutation per thread: `gh api graphql -f query='mutation { a:resolveReviewThread(input:{threadId:"<id1>"}){thread{isResolved}} b:resolveReviewThread(input:{threadId:"<id2>"}){thread{isResolved}} }'`. Return to 8a.

   Apply is complete only when the PR is **merged with every required check passing**.

9. **After merge:** tell the user apply is complete and run `/opsx:archive` (spec sync, single-commit archive via a doc-branch PR with auto-merge, branch prune). Do not archive or push to the default branch from this skill.

## Guardrails

- Never skip the pre-commit review or local CI-equivalent validation; never force-merge or use `--admin`.
- Keep changes minimal and scoped to each task; update checkboxes immediately.
- Never wait for a human to report merge, comments, or CI results; poll as in step 8.
- A failing required check is never "someone else's problem": fix it, or pause and ask if the gate itself looks wrong.
- The change as a whole is done only after the archive stage completes.

## Output

Keep status output to short one-liners: current task `N/M`, review result, PR URL, loop state (`checks: 2 pass / 1 fail; threads: 1 open`), and final `Apply complete: PR merged, all required checks passed. Run /opsx:archive.` When paused, state the issue and 2-3 options.
