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

   - For `spec-driven`, this typically includes proposal, specs, design, and tasks
   - For other schemas, follow `contextFiles` exactly as returned by the CLI

5. **Show current progress**

   Display:

   - Schema being used
   - Progress in `N/M tasks complete` form
   - Remaining tasks overview
   - Dynamic instruction from the CLI

   If implementation is just starting, explicitly instruct the user to sync from the default branch before creating or checking out the feature branch:

   - `git checkout <default-branch>`
   - `git pull --ff-only`
   - `git checkout -b <feature-branch>`

6. **Implement tasks**

   For each pending task:

   - Show which task is being worked on
   - Make the required code changes
   - Keep changes minimal and focused
   - Mark the task complete in the tasks file by changing `- [ ]` to `- [x]`
   - Continue to the next task

   Pause if:

   - The task is unclear
   - Implementation reveals a design issue
   - An error or blocker is encountered
   - The user interrupts

7. **On completion or pause, show status**

   Display:

   - Tasks completed this session
   - Overall progress in `N/M tasks complete` form
   - If all done, suggest archive
   - If paused, explain why and wait for guidance

## Output During Implementation

```text
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>
...implementation happening...
✓ Task complete

Working on task 4/7: <task description>
...implementation happening...
✓ Task complete
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

All tasks complete. Ready to archive this change.
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
- If a task is ambiguous, pause and ask before implementing
- If implementation reveals issues, pause and suggest artifact updates
- Keep code changes minimal and scoped to each task
- Update the task checkbox immediately after completing each task
- Pause on errors, blockers, or unclear requirements; do not guess
- Use `contextFiles` from CLI output and do not assume specific file names

## Fluid Workflow Integration

This skill supports the `actions on a change` model:

- It can be invoked anytime: before all artifacts are done if tasks exist, after partial implementation, or interleaved with other actions
- It allows artifact updates: if implementation reveals design issues, suggest updating artifacts rather than forcing a rigid phase boundary
