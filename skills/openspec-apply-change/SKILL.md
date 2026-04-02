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

   - `schemaName`: The workflow being used, for example `spec-driven`
   - Which artifact contains the tasks, typically `tasks` for `spec-driven`
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

   - For `spec-driven`, this typically includes proposal, specs, design, tasks, and tests.
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

7. **Implement tasks (TDD)**

   For each pending task, follow a strict Test-Driven Development process:

   1.  **Write a failing test:**
        - Announce "Writing failing test for: <task description>".
        - Add a new test case to `tests.md`.
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

8. **Commit and open PR** *(when all tasks complete)*

   After all tasks are marked complete and all local validation passes:

   - Commit all changes to the working branch with a clear message
   - Push the working branch to remote
   - Before opening the PR, read `proposal.md` and extract any issue references listed under `## GitHub Issues`. Parse lines of the form `#N` or `owner/repo#N` (skip blank lines and the HTML comment block).
   - Build a closing-keywords block from those references, e.g.:
     ```
     Closes #42
     Closes myorg/repo#7
     ```
     If there are no issue references, omit this block entirely.
   - Open a PR from the working branch to the default branch. Include the closing-keywords block at the end of the PR body so GitHub automatically closes the linked issues on merge.
   - Announce the PR URL
   - **Wait 3 minutes** before doing anything else — this gives CI time to start and reviewers time to leave early comments

9. **PR review and CI loop** *(iterate until the PR is fully clean)*

   Repeat the following cycle until **all CI checks are green AND there are zero open review comments**:

   **9a. Assess current state**

   Run both checks in parallel:

   - `gh pr checks <PR-URL>` — list all CI check statuses
   - `gh api graphql -f query='{ repository(owner:"<owner>", name:"<repo>") { pullRequest(number:<num>) { reviewThreads(first:50) { nodes { id isResolved comments(first:1) { nodes { body } } } } } } }'` — list all review threads with their resolved status

   **9b. Address failing CI checks** *(if any)*

   For each failing check:

   - Read the failure output (`gh run view <run-id> --log-failed`)
   - Diagnose the root cause
   - Fix the issue in code, commit, and push
   - After pushing, **wait 1 minute** to let CI re-trigger and allow any comments you previously addressed to auto-resolve
   - After the 1-minute wait, re-run the GraphQL query from 9a; for any thread where you addressed the comment but it still shows `isResolved: false`, resolve it explicitly:
     ```graphql
     mutation {
       resolveReviewThread(input: { threadId: "<thread-id>" }) {
         thread { id isResolved }
       }
     }
     ```
     Run this via: `gh api graphql -f query='mutation { resolveReviewThread(input:{threadId:"<thread-id>"}) { thread { id isResolved } } }'`
   - Return to 9a

   **9c. Address open review comments** *(if any, after CI is green)*

   For each unresolved review thread:

   - Read the comment body
   - Implement the requested change, or leave a polite reply if the request is unclear or out of scope
   - Commit the fix to the working branch and push
   - **Wait 1 minute** to allow the comment to auto-resolve and CI to re-trigger
   - After the 1-minute wait, re-run the GraphQL query; for any thread you addressed that still shows `isResolved: false`, resolve it explicitly using the mutation above
   - Return to 9a to re-check CI (your push may have introduced new failures)

   **9d. Exit condition**

   When `gh pr checks` shows all checks passing **and** the GraphQL query returns zero threads with `isResolved: false`, exit the loop and proceed to step 10.

10. **Enable auto-merge**

    Only reached when **all CI checks are green and all review threads are resolved**:

    - Enable auto-merge on the PR: `gh pr merge <PR-URL> --auto --merge`
    - Announce that auto-merge has been enabled
    - **Never force-merge** — wait for the merge to complete naturally, or continue if a human force-merges

11. **Post-merge steps** *(after PR merges)*

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

All tasks complete. Opening PR — waiting 3 minutes before first check.
```

## Output During PR Loop

```text
## PR Review Loop — <PR-URL>

**CI checks:** 2 passing, 1 failing (build)
**Open threads:** 1 unresolved

→ Addressing failing check: build
  Diagnosed: missing env var in workflow
  Fixed, committed, pushed
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
- **Adhere strictly to the TDD process for all implementation.**
- If a task is ambiguous, pause and ask before implementing
- If implementation reveals issues, pause and suggest artifact updates
- Keep code changes minimal and scoped to each task
- Update the task checkbox immediately after completing each task
- Pause on errors, blockers, or unclear requirements; do not guess
- Use `contextFiles` from CLI output and do not assume specific file names
- In a git repo: Step 1 is always checkout default branch + pull; Step 2 is always create working branch + push to remote immediately
- After all tasks are locally complete and validated, always commit + push + open PR before declaring done
- After opening a PR, always wait 3 minutes before inspecting comments or checks
- After every push, always wait 1 minute before re-assessing — lets CI re-trigger and auto-resolve stale comment threads
- If a review thread you addressed is still open after the 1-minute wait, resolve it explicitly via the GitHub GraphQL `resolveReviewThread` mutation — never leave addressed threads dangling
- Never enable auto-merge until **both** conditions are simultaneously true: all CI checks green **and** zero open review threads
- Monitor comments and CI in a single unified loop (step 9); iterate until both exit conditions are met, then and only then enable auto-merge
- Never force-merge; enable auto-merge and wait
- Post-merge archive must be a single atomic commit: copy to archive location and delete original path must be staged together, never split across two commits

## Fluid Workflow Integration

This skill supports the `actions on a change` model:

- It can be invoked anytime: before all artifacts are done if tasks exist, after partial implementation, or interleaved with other actions
- It allows artifact updates: if implementation reveals design issues, suggest updating artifacts rather than forcing a rigid phase boundary
