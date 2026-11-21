---
description: "Implement tasks from an OpenSpec change (Experimental)"
---

# Apply Change

Implement tasks from an OpenSpec change and drive the PR to merge. Archive is a separate stage (`/opsx:archive`). This skill is the single home for the implement/review/PR-loop process; `tasks.md` and config reference it.

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

   Read the `tasks`, `tests`, and `specs` files from `contextFiles`. Read `proposal.md` and `design.md` only on first start of the change, when a task is ambiguous, or to extract `## GitHub Issues`. Follow `contextFiles` as returned; do not assume file names.

3. **Enter the change's worktree**

   All implementation happens in `.worktrees/<name>`, never the primary checkout. `cd` into it if it exists (`git worktree list`); otherwise create it as in propose step 3 (or `git worktree add .worktrees/<name> <name>` if the branch already exists on remote). Confirm the branch is pushed. Never checkout a different branch in the primary checkout.

4. **Preflight**

   Verify `pr-review-toolkit:review-pr` is available. If not, halt, tell the user the plugin is required with install guidance, and wait for confirmation.

5. **Issue lifecycle: in-progress** *(only if the change is issue-driven; otherwise skip silently)*

   `gh issue edit #N --add-label "in-progress"`. Discover the project (`gh project list --owner <owner> --format json`), resolve the status option matching "In Progress" (`gh project field-list <n> --owner <owner> --format json`), move the item with `gh project item-edit`. If no item is found, warn and continue. If the token lacks the `project` scope, tell the user to run `gh auth refresh -s project`, skip the project update, and still apply the label.

6. **Implement tasks (strict BDD/TDD)**

   For each pending task, with one-line progress updates (`task N/M: <desc>`):

   1. Red: add the behavior-focused case to `tests.md`, write the test, run it, confirm it fails.
   2. Green: write the minimum code to pass; run tests.
   3. Refactor with tests green.
   4. Mark the task `- [x]` immediately.

   Pause (do not guess) if a task is unclear, implementation reveals a design issue (suggest artifact updates), an error or blocker occurs, or the user interrupts.

7. **Local validation (CI-equivalent)**

   Run the repo's own equivalents of its CI checks: tests, build, lint/static analysis/type checks, security checks, and coverage requirements. Find commands and thresholds in the README / CLAUDE.md / AGENTS.md / CI config. If every changed file is `.md`, build only is required. All must pass before any push. Never lower thresholds or skip/disable checks to get green; if a gate looks wrong, pause and ask the user.

8. **Pre-commit review** *(before every commit)*

   Spawn a sub-agent to run `openspec-review-code`, passing the SHA of the last reviewed commit if there is one (the first review has none, so it covers the whole branch). The finding list is internal: do not show it to the user or ask for confirmation. Apply every clearly-correct fix, skip ambiguous ones silently, re-run validation, commit, and record the new HEAD as the last reviewed commit. Pause only if a finding contradicts the spec and needs a user decision.

9. **Commit, push, open PR** *(all tasks done, validation green)*

   - Commit and push the working branch.
   - Extract `#N` / `owner/repo#N` references from `## GitHub Issues` in `proposal.md` (ignore list markers, blank lines, the HTML comment). If any exist, the PR body MUST end with a `Closes <ref>` line per reference.
   - Open the PR to the default branch and announce the URL.
   - If issue-driven: `gh issue edit #N --add-label "in-review" --remove-label "in-progress"` and move the project item to the status matching "In Review" (same discovery as step 5; warn and skip if not found).

10. **PR triage loop** *(autonomous until merged; never wait for a human to report comments or merge; never use fixed sleeps)*

    Immediately start in parallel: (a) a sub-agent running `pr-review-toolkit:review-pr`; (b) `gh pr checks <PR-URL> --required --watch --fail-fast` (returns on first failure or when all required checks finish). Checks finishing is not the end of monitoring: after it returns, re-query threads and state; while waiting for merge or new reviews, re-check `gh pr view <PR-URL> --json state,mergeStateStatus,headRefOid` at spaced intervals (about 60 seconds), running the thread query again only when the state, head commit, or review activity changed.

    Each iteration, collect every signal, then fix everything in one commit:

    - Failing required checks: `gh pr checks <PR-URL> --required --json name,bucket,link`; for failures `gh run view <run-id> --log-failed`. Quality-gate and coverage failures are fixed in code, never waived.
    - Unresolved review threads: `gh api graphql` on `pullRequest.reviewThreads(first:100) { pageInfo { hasNextPage endCursor } nodes { id isResolved isOutdated path original: comments(first:1) { nodes { body author { login } } } latest: comments(last:1) { nodes { body author { login } } } } }`; paginate only while `hasNextPage` is true. (`gh pr view --json` has no `reviewThreads` field.) Consider only unresolved threads; read the original comment and the latest reply (fetch the full thread when they differ) so the finding is not hidden by replies.
    - review-pr findings from the sub-agent.

    Then run local validation (step 7) and the pre-commit review (step 8; incremental), push once, reply to each addressed thread, resolve them all in one call with aliased mutations (`a:resolveReviewThread(input:{threadId:"<id1>"}){thread{isResolved}} b:resolveReviewThread(...)`), and re-run the watch.

    **Iterate at most twice.** After two fix-and-push cycles, the next assessment is a third review; if it still shows failing required checks, unresolved threads, or findings, stop and escalate to the user with the remaining items. Never start a fourth iteration.

    When the review-pr sub-agent reports zero findings, no thread is unresolved, and required checks pass, enable auto-merge: `gh pr merge <PR-URL> --auto --merge` (never `--admin`, never force-merge). Then keep watching (spaced `gh pr view <PR-URL> --json state,mergeStateStatus` checks, about 60 seconds apart) until `MERGED`; on `CLOSED`, notify the user and stop. If new comments or failures appear after auto-merge is enabled, re-enter the loop.

11. **Finish**

    Apply is complete only when the PR is **merged with every required CI check and quality gate passing**. Tell the user and run `/opsx:archive` (spec sync, single-commit archive via doc-branch PR, worktree removal, branch prune). Do not archive or push to the default branch from this skill.

## Guardrails

- Never skip the pre-commit review or local CI-equivalent validation; never force-merge or use `--admin`.
- Keep changes minimal and scoped to each task; update checkboxes immediately.
- Never wait for a human to report merge, comments, or CI results.
- A failing required check is never someone else's problem: fix it, or pause and ask if the gate itself looks wrong.
- The change as a whole is done only after the archive stage completes.

## Output

Keep status output to short one-liners: current task `N/M`, PR URL, loop state (`checks: 2 pass / 1 fail; threads: 1 open`), and final `Apply complete: PR merged, all required checks passed. Run /opsx:archive.` When paused, state the issue and 2-3 options.
