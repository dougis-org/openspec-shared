---
name: openspec-apply-change
description: Implement tasks from an OpenSpec change. Use when the user wants to start implementing, continue implementation, or work through tasks.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
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

5. **Sync with default branch**

   Before starting implementation, you MUST sync from the default branch.

   - `git checkout <default-branch>`
   - `git pull --ff-only`
   - `git checkout -b <feature-branch>` or `git checkout <feature-branch>` if it already exists.

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
   - If all done, proceed to step 8
   - If paused, explain why and wait for guidance

8. **Pre-PR self-review** *(before committing)*

   Before committing, spawn a sub-agent with a code reviewer persona to review all changes as if they were already in a pull request. The goal is to catch complexity, duplication, and quality issues before any code is committed.

   **Launch the sub-agent:**

   Use the Agent tool with the following prompt (fill in `<default-branch>`):

   > You are a senior code reviewer performing a pre-merge review. Your job is to review the staged and unstaged changes in this repository as if they had just been submitted in a pull request.
   >
   > Run `git diff <default-branch>...HEAD` (and `git diff HEAD` for unstaged changes) to see all changes introduced by the feature branch.
   >
   > Review the diff with the following goals — **only report issues you are confident about**:
   >
   > 1. **Reduce complexity** — identify logic or structure that is needlessly complex and suggest a simpler equivalent.
   > 2. **Eliminate duplication** — spot repeated logic or structure that could be consolidated.
   > 3. **Improve quality** — flag naming that is unclear, instructions or logic that are ambiguous or contradictory, or anything likely to confuse a future reader.
   >
   > Do **not** suggest adding comments, docstrings, type annotations, or test coverage for code that is not part of the diff. Do **not** propose speculative abstractions or features beyond what the diff introduces.
   >
   > Return a structured review report in this exact format, writing "None" under any section with no findings:
   >
   > ```
   > ## Pre-PR Review Report
   >
   > ### Complexity Issues
   > - <file>:<line> — <description> — Suggested fix: <concise fix>
   >
   > ### Duplication Issues
   > - <file>:<line> — <description> — Suggested fix: <concise fix>
   >
   > ### Quality Issues
   > - <file>:<line> — <description> — Suggested fix: <concise fix>
   > ```

   **Act on the review:**

   Read the sub-agent's report. For each issue:

   - If the fix is clearly correct and within scope, apply it immediately.
   - If the fix is ambiguous or out of scope, skip it and note it in the commit message or PR description.

   After applying accepted fixes, re-run all tests to confirm they still pass before continuing to step 9.

9. **Commit and open PR** *(when all tasks complete)*

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
   - Open a PR from the working branch to the default branch. Include the closing-keywords block at the end of the PR body so GitHub automatically closes the linked issues on merge.
   - Announce the PR URL
   - **Wait 3 minutes** before doing anything else — this gives CI time to start and reviewers time to leave early comments

10. **PR review and CI loop** *(iterate until the PR is fully clean)*

   Repeat the following cycle until **all CI checks are green AND there are zero open review comments**:

   **10a. Assess current state**

   Run both checks in parallel:

   - `gh pr checks <PR-URL>` — list all CI check statuses
   - `gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>") { pullRequest(number:<num>) { reviewThreads(first:100) { pageInfo { hasNextPage endCursor } nodes { id isResolved comments(last:1) { nodes { body author { login } createdAt } } } } } } }'` — list all review threads with their resolved status and latest comment

   If `pageInfo.hasNextPage` is `true`, paginate using `after:"<endCursor>"` until all threads are fetched. In practice, PRs rarely exceed 100 threads; if one does, retrieve all pages before proceeding.

   **10b. Address all open issues** *(CI failures and review comments together)*

   Gather every problem in one pass:

   - For each **failing CI check**: read the failure output (`gh run view <run-id> --log-failed`), diagnose, and fix in code.
   - For each **unresolved review thread**: read the latest comment body, and either implement the requested change or draft a polite reply if the request is unclear or out of scope.

   Once all fixes and replies are ready, **commit everything and push once**. Batching into a single push minimises unnecessary CI runs and wait time.

   After pushing, **wait 1 minute** to let CI re-trigger and allow addressed threads to auto-resolve.

   After the 1-minute wait, re-run the GraphQL query from 10a; for any thread you addressed that still shows `isResolved: false`, resolve it explicitly:

   Run this via: `gh api graphql -f query='mutation { resolveReviewThread(input: { threadId: "<thread-id>" }) { thread { id isResolved } } }'`

   Return to 10a.

   **10c. Exit condition**

   When `gh pr checks` shows all checks passing **and** the GraphQL query returns zero threads with `isResolved: false` across all pages, exit the loop and proceed to step 11.

11. **Enable auto-merge**

    Only reached when **all CI checks are green and all review threads are resolved**:

    - Enable auto-merge on the PR: `gh pr merge <PR-URL> --auto --merge`
    - Announce that auto-merge has been enabled
    - **Never force-merge** — wait for the merge to complete naturally, or continue if a human force-merges

12. **Post-merge steps** *(after PR merges)*

    - `git checkout <default-branch>` and `git pull --ff-only`
    - Verify the merged changes appear on the default branch
    - Mark any remaining tasks as complete (`- [x]`) in the tasks file
    - Sync approved spec deltas to `openspec/specs/` if applicable
    - Archive the change: move the entire `openspec/changes/<name>/` directory to `openspec/changes/archive/YYYY-MM-DD-<name>/` — stage **both** the new location and the removal of the original in one `git add` so they land in a single commit; never split the copy and delete into separate commits
    - Commit and push the archive to the default branch
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

All tasks complete. Running pre-PR self-review before committing.
```

## Output During Pre-PR Review

```text
## Pre-PR Self-Review

→ Spawning code reviewer sub-agent to review all changes...

## Pre-PR Review Report

### Complexity Issues
- src/foo.ts:42 — nested ternary hard to follow — Suggested fix: extract to named function

### Duplication Issues
- None

### Quality Issues
- src/bar.ts:17 — variable name `x` is unclear at call site — Suggested fix: rename to `retryCount`

→ Applying 2 accepted fixes...
→ Re-running tests to confirm fixes pass... ✓

Pre-PR review complete — proceeding to commit.
```

## Output During PR Loop

```text
## PR Review Loop — <PR-URL>

**CI checks:** 2 passing, 1 failing (build)
**Open threads:** 1 unresolved

→ Gathering all issues before pushing:
  CI: build failing — diagnosed: missing env var in workflow — fix ready
  Thread: "<comment body>" — change implemented — fix ready

→ All fixes batched — committing and pushing once
  Waiting 1 minute for CI to re-trigger and comments to auto-resolve...

→ Re-checking state after wait
  Thread "<comment body>" still open — resolving via GraphQL resolveReviewThread
  ✓ Thread resolved

**CI checks:** 3 passing ✓
**Open threads:** 0 ✓

→ All checks green and no open threads — enabling auto-merge
```

## Output After Post-Merge

```text
## Change Complete

**Change:** <change-name>
**Schema:** <schema-name>
**PR:** merged ✓
**Default branch:** verified ✓
**Archive:** openspec/changes/archive/YYYY-MM-DD-<name>/ ✓
**Branch cleanup:** <feature-branch> deleted ✓
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
- **Adhere strictly to the BDD/TDD process for all implementation.**
- If a task is ambiguous, pause and ask before implementing
- If implementation reveals issues, pause and suggest artifact updates
- Keep code changes minimal and scoped to each task
- Update the task checkbox immediately after completing each task
- Pause on errors, blockers, or unclear requirements; do not guess
- Use `contextFiles` from CLI output and do not assume specific file names
- In a git repo: Step 1 is always checkout default branch + pull; Step 2 is always create working branch + push to remote immediately
- Never skip step 8 (pre-PR self-review); the review sub-agent only reports — the main agent applies fixes and re-runs tests before committing
- After all tasks are locally complete, validated, and the pre-PR review is done, always commit + push + open PR before declaring done
- After opening a PR, always wait 3 minutes before inspecting comments or checks
- After every push, always wait 1 minute before re-assessing — lets CI re-trigger and auto-resolve stale comment threads
- If a review thread you addressed is still open after the 1-minute wait, resolve it explicitly via the GitHub GraphQL `resolveReviewThread` mutation — never leave addressed threads dangling
- Always paginate review thread queries when `pageInfo.hasNextPage` is `true` — never assume 100 threads is sufficient without checking
- In each loop iteration, fix all CI failures and address all open review comments before pushing — never push after fixing just one issue; batch all fixes into a single commit+push to minimise CI runs
- Never enable auto-merge until **both** conditions are simultaneously true: all CI checks green **and** zero open review threads (across all pages)
- Monitor comments and CI in a single unified loop (step 10); iterate until both exit conditions are met, then and only then enable auto-merge
- Never force-merge; enable auto-merge and wait
- Post-merge archive must be a single atomic commit: copy to archive location and delete original path must be staged together, never split across two commits

## Fluid Workflow Integration

This skill supports the `actions on a change` model:

- It can be invoked anytime: before all artifacts are done if tasks exist, after partial implementation, or interleaved with other actions
- It allows artifact updates: if implementation reveals design issues, suggest updating artifacts rather than forcing a rigid phase boundary
