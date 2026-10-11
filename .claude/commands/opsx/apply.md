---
name: "OPSX: Apply"
description: "Implement tasks from an OpenSpec change (Experimental)"
category: Workflow
tags: [workflow, artifacts, experimental]
---

# Apply Change

Implement tasks from an OpenSpec change.

## Input

Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

## Steps

1. **Select the change**

   If a name is provided, use it. Otherwise:

   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, run `openspec list --json` to get available changes and use the **AskUserQuestion tool** to let the user select

   Always announce `Using change: [change-name]` and how to override, for example `/opsx:apply [other-change]`.

2. **Check status to understand the schema**

   ```bash
   openspec status --change "<name>" --json
   ```

   Parse the JSON to understand:

   - `schemaName`: The workflow being used, for example `sdd-with-feedback-loop`
   - Which artifact contains the tasks, typically `tasks` for `sdd-with-feedback-loop`
   - Check for a `tests` artifact. If it does not exist, create it from the `tests.template.md` template.

3. **Get apply instructions**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   This returns:

   - Context file paths, which vary by schema
   - Progress totals and remaining work
   - Task list with status
   - Dynamic instruction based on current state

   **Handle states:**

   - If `state: "blocked"`, show which artifacts are missing and suggest running the propose skill first
   - If `state: "all_done"`, suggest archive
   - Otherwise, proceed to implementation

4. **Read context files**

   Read the files listed in `contextFiles` from the apply instructions output.

   - For `sdd-with-feedback-loop`, this typically includes proposal, specs, design, tasks, and tests.
   - For other schemas, follow `contextFiles` exactly as returned by the CLI

5. **Enter the change's dedicated worktree**

   All implementation happens inside a dedicated git worktree, never in the primary checkout — this is what lets multiple agents implement different changes from the same repo clone in parallel.

   - Run `git worktree list` to check whether `.worktrees/<name>` already exists (it normally does, created during propose or explore).
   - If it exists, `cd` into it.
   - If it does not exist yet (e.g. the change predates this convention, or was created manually), create it from the primary checkout: `git fetch origin`, then `git worktree add .worktrees/<name> -b <name> origin/<default-branch>` (or `git worktree add .worktrees/<name> <name>` if the branch already exists on remote), then `cd` into it.
   - Confirm the branch is pushed to remote; if not, `git push -u origin <feature-branch>` immediately.
   - Never `git checkout` a different branch inside the primary checkout to do this work — that would disrupt any other agent or human using that checkout concurrently.

6. **Show current progress**

   Display:

   - Schema being used
   - Progress in `N/M tasks complete` form
   - Remaining tasks overview
   - Dynamic instruction from the CLI

7. **Implement tasks (BDD/TDD)**

   For each pending task, follow a strict BDD/TDD process:

   1.  **Write a failing test:**
      - Announce "Writing failing BDD/TDD test for: <task description>".
      - Add a new behavior-focused test case to `tests.md`.
      - Write the test code in the appropriate test file.
      - Run the test and confirm that it fails as expected.

   2.  **Write code to pass the test:**
        - Announce "Writing code to pass test for: <task description>".
        - Write the minimum amount of implementation code to make the test pass.
        - Run the tests and confirm that all tests now pass.

   3.  **Refactor:**
        - Announce "Refactoring code for: <task description>".
        - Refactor the implementation code and tests for clarity, efficiency, and to meet coding standards.
        - Ensure all tests still pass after refactoring.

   4.  **Mark task complete:**
        - Mark the task as complete in `tasks.md` by changing `- [ ]` to `- [x]`.

   Pause if:

   - The task is unclear
   - Implementation reveals a design issue
   - An error or blocker is encountered
   - The user interrupts

8. **On completion or pause, show status**

   Display:

   - Tasks completed this session
   - Overall progress in `N/M tasks complete` form
   - If all done, proceed to step 9
   - If paused, explain why and wait for guidance

9. **Pre-Commit Code Review** *(before every commit)*

    Before committing, you MUST spawn a dedicated sub-agent to run the `openspec-review-code` skill.

    **Launch the sub-agent:**
    Use the Agent tool and instruct it to: "Run the openspec-review-code skill".

    **Act on the review — DO NOT STOP:**
    The sub-agent's report is internal working state, not a user-facing output. You MUST NOT present the findings list to the user, pause, or ask for confirmation. Read the report internally, apply every clearly-correct fix directly to the code, then re-run all tests to confirm they pass, and proceed to commit — all without user interaction. If a finding is ambiguous, skip it and continue silently. Only pause for user input if a finding directly contradicts the spec and resolving it requires a decision only the user can make.

10. **Commit and open PR** *(when all tasks complete)*

   After all tasks are marked complete, all local validation passes, and the pre-PR review fixes have been applied:

   - Commit all changes to the working branch with a clear message
   - Push the working branch to remote
   - Before opening the PR, read `proposal.md` and extract any issue references listed under `## GitHub Issues`. Extract references of the form `#N` or `owner/repo#N` from those lines, ignoring Markdown list markers (`-`, `*`), leading/trailing whitespace, blank lines, and the HTML comment block.
   - Build a closing-keywords block from those references, e.g.:
     ```
     Closes #42
     Closes myorg/repo#7
     ```
     If there are no issue references, omit this block entirely.
   - **REQUIRED:** If `proposal.md` lists any GitHub issue references, the PR body MUST include the closing-keywords block. Never open a PR against an issue-driven change without it.
   - Open a PR from the working branch to the default branch. Include the closing-keywords block at the end of the PR body so GitHub automatically closes the linked issues on merge.
   - Announce the PR URL
   - Spawn a sub-agent to run `pr-review-toolkit:review-pr` in parallel with the CI watch below. Enable auto-merge (`gh pr merge <PR-URL> --auto --merge`, **NEVER** `--admin`) only after review-pr reports zero findings and no review thread is unresolved.
   - Do not sleep. Start `gh pr checks <PR-URL> --required --watch --fail-fast` immediately; it returns on the first failure or when all required checks finish.

11. **PR review and CI loop** *(iterate until the PR merges)*

   Repeat until the PR is detected as merged. Never wait for a human to report the merge or new comments.

   **11a. Assess current state** *(run in parallel)*

   - `gh pr checks <PR-URL> --required --json name,bucket,link` — required CI checks (`bucket` is `pass`, `fail`, `pending`, `skipping` or `cancel`)
   - `gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>") { pullRequest(number:<num>) { reviewThreads(first:100) { pageInfo { hasNextPage endCursor } nodes { id isResolved isOutdated path comments(last:1) { nodes { body author { login } createdAt } } } } } } }'` — paginate with `after:"<endCursor>"` while `hasNextPage` is `true`

   **11b. Address all open issues in one pass**

   - For each required check with `bucket: "fail"`: `gh run view <run-id> --log-failed`, diagnose, fix in code.
   - For each unresolved thread: implement the change, or reply politely with evidence if unclear or out of scope.

   Run step 9 (pre-commit code review), run local validation, then commit and push once. Immediately reply to and resolve each addressed thread: `gh api graphql -f query='mutation { resolveReviewThread(input: { threadId: "<thread-id>" }) { thread { id isResolved } } }'`. Then re-run `gh pr checks <PR-URL> --required --watch --fail-fast`.

   **Iteration cap:** count each fix-and-push cycle. After two, the next assessment (11a plus review-pr) is the third review; if it still shows failing required checks, unresolved threads, or findings, stop and escalate to the user with the remaining items listed. Do not start a fourth iteration.

   **11c. Check for merge**

   `gh pr view <PR-URL> --json state,mergedAt`:
   - `MERGED` — proceed to post-merge steps
   - `CLOSED` — notify the user; skip post-merge steps
   - `OPEN` — return to 11a

12. **Post-merge steps** *(after PR merges)*

    - From the primary checkout: `git checkout <default-branch>` and `git pull --ff-only`
    - Verify the merged changes appear on the default branch
    - Mark any remaining tasks as complete (`- [x]`) in the tasks file
    - Sync approved spec deltas to `openspec/specs/` if applicable
    - Archive the change: move the entire `openspec/changes/<name>/` directory to `openspec/changes/archive/YYYY-MM-DD-<name>/` — stage **both** the new location and the removal of the original in one `git add` so they land in a single commit; never split the copy and delete into separate commits
    - Commit and push the archive to the default branch
    - Remove the change's dedicated worktree: `git worktree remove .worktrees/<name>`
    - Run `git fetch --prune` and `git branch -d <feature-branch>` to clean up

## Output During Implementation

```text
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>

1.  **Test:** Writing failing test for <task description>.
2.  **Implement:** Writing code to pass test.
3.  **Refactor:** Refactoring code.

✓ Task complete

Working on task 4/7: <task description>
...
```

## Output On Completion

```text
## Implementation Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 7/7 tasks complete ✓

### Completed This Session
- [x] Task 1
- [x] Task 2
...

All tasks complete. Running pre-commit review before committing.
```

## Output During Pre-PR Review

```text
→ Running pre-commit code review (sub-agent)...
→ Applying fixes from review... ✓
→ Tests pass after fixes ✓
→ Proceeding to commit.
```

The sub-agent's finding list is NOT shown to the user. Apply findings silently and continue.

## Output During PR Loop

```text
## PR Review Loop — <PR-URL>

Auto-merge: enabled ✓

**CI checks:** 2 passing, 1 failing (build)
**Open threads:** 1 unresolved

→ Gathering all issues before pushing:
  CI: build failing — diagnosed: missing env var in workflow — fix ready
  Thread: "<comment body>" — change implemented — fix ready

→ All fixes batched — committing and pushing once
  Thread "<comment body>" — replied and resolving via GraphQL resolveReviewThread
  ✓ Thread resolved
→ Re-watching required checks (gh pr checks --watch --fail-fast)

**CI checks:** 3 passing ✓
**Open threads:** 0 ✓

→ Polling for merge... PR state: MERGED ✓
```

## Output After Post-Merge

```text
## Change Complete

**Change:** <change-name>
**Schema:** <schema-name>
**PR:** merged ✓
**Default branch:** verified ✓
**Archive:** openspec/changes/archive/YYYY-MM-DD-<name>/ ✓
**Worktree cleanup:** .worktrees/<name> removed, <feature-branch> deleted ✓
```

## Output On Pause

```text
## Implementation Paused

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 4/7 tasks complete

### Issue Encountered
<description of the issue>

**Options:**
1. <option 1>
2. <option 2>
3. Other approach

What would you like to do?
```

## Guardrails

- Keep going through tasks until done or blocked
- Always read context files before starting
- If `proposal.md` lists any GitHub issue references, the PR body MUST include a `Closes #N` line for each one — never omit this
- **Adhere strictly to the BDD/TDD process for all implementation.**
- If a task is ambiguous, pause and ask before implementing
- If implementation reveals issues, pause and suggest artifact updates
- Keep code changes minimal and scoped to each task
- Update the task checkbox immediately after completing each task
- Pause on errors, blockers, or unclear requirements; do not guess
- Use `contextFiles` from CLI output and do not assume specific file names
- In a git repo: all implementation work happens inside the change's dedicated worktree at `.worktrees/<name>`; create it (from the default branch) if it doesn't already exist, then confirm the branch is pushed to remote — never checkout a different branch in the primary checkout to do this work
- Never skip step 9 (pre-commit code review); you MUST spawn a sub-agent to run the `openspec-review-code` skill before every commit, and the primary agent must automatically address all findings from the sub-agent before committing.
- **NEVER stop after receiving the sub-agent review report.** Do not present the findings list to the user. Do not ask for confirmation. Apply all clearly-correct fixes silently, re-run tests, and continue to commit — all without user interaction. Showing the finding list to the user and waiting is the exact wrong behavior.
- After all tasks are locally complete, validated, and the pre-commit review is done, always commit + push + open PR before declaring done
- After opening a PR, never sleep: start `gh pr checks --required --watch --fail-fast` and the `pr-review-toolkit:review-pr` sub-agent immediately. Enable auto-merge only after review-pr reports zero findings and no thread is unresolved.
- After every push, reply to and resolve each addressed review thread immediately via the GitHub GraphQL `resolveReviewThread` mutation — never leave addressed threads dangling
- **Iterate at most twice.** After two fix-and-push iterations, run a third review; if review-pr findings, required checks, or review threads still raise issues, stop, escalate to the user with the remaining items listed, and wait for guidance. Never start a fourth iteration.
- Always paginate review thread queries when `pageInfo.hasNextPage` is `true` — never assume 100 threads is sufficient without checking
- In each loop iteration, fix all **required** CI failures and address all open review comments before pushing. Do not exit the loop while any required checks fail or threads are unresolved.
- Monitor comments and CI in a single unified loop (step 10); after each iteration poll `gh pr view --json state` autonomously — never wait for a human to report new comments or that the PR has merged
- Never force-merge using `--admin`; enable auto-merge once the review gate passes and let GitHub merge when all required checks pass and threads are resolved.
- Post-merge archive must be a single atomic commit: copy to archive location and delete original path must be staged together, never split across two commits

## Fluid Workflow Integration

This skill supports the `actions on a change` model:

- It can be invoked anytime: before all artifacts are done if tasks exist, after partial implementation, or interleaved with other actions
- It allows artifact updates: if implementation reveals design issues, suggest updating artifacts rather than forcing a rigid phase boundary
