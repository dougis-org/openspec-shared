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
   - Open a PR from the working branch to the default branch
   - Announce the PR URL

9. **Monitor PR comments** *(iterative loop)*

   Poll the PR for new review comments. For each unresolved comment:

   - Read the comment
   - Implement the requested change or respond if the request is unclear
   - Commit the fix to the working branch and push
   - Mark the comment as resolved if possible
   - Repeat until no unresolved blocking comments remain

10. **Enable auto-merge**

    Once all required CI checks are green and no blocking review comments remain:

    - Enable auto-merge on the PR
    - **Never force-merge** — wait for the merge to complete naturally, or continue if a human force-merges

11. **Monitor CI checks** *(iterative loop)*

    After each push, check all CI check statuses on the PR. For any failing check:

    - Read the failure output
    - Diagnose the root cause
    - Fix the issue, commit, and push
    - Repeat until all required checks pass

    The comment and CI loops run concurrently: if both comments and CI failures are present, address comments first, then confirm CI passes after the resulting push.

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

All tasks complete. Opening PR and entering review/CI monitoring loop.
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
- Monitor PR comments and CI checks in iterative loops until the PR is fully clean
- Never force-merge; enable auto-merge and wait
- Post-merge archive must be a single atomic commit: copy to archive location and delete original path must be staged together, never split across two commits

## Fluid Workflow Integration

This skill supports the `actions on a change` model:

- It can be invoked anytime: before all artifacts are done if tasks exist, after partial implementation, or interleaved with other actions
- It allows artifact updates: if implementation reveals design issues, suggest updating artifacts rather than forcing a rigid phase boundary
