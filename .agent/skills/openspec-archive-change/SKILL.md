---
name: openspec-archive-change
description: Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
---

# Archive Change

Archive a completed change in the experimental workflow.

## Input

Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

## Steps

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes. Use the **AskUserQuestion tool** to let the user select.

   Show only active changes (not already archived).
   Include the schema used for each change if available.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check Pull Request Status**

   Before proceeding, you MUST verify the status of the pull request associated with the change.

   - **Find the PR:** Use the git history or GitHub CLI (`gh pr list`) to find the PR associated with the feature branch for the change.
   - **Check Merge Status:** The PR MUST be merged. If it is not merged, the change cannot be archived.
   - **Check CI Status:** All CI checks on the PR MUST have passed. If any have failed, the change cannot be archived.
   - **Check for Comments:** All review comments, including those from AI agents, MUST be addressed and resolved.

   If any of these conditions are not met, you MUST NOT proceed with the archive. Inform the user of the outstanding issues (e.g., "CI checks failed", "Open review comments exist", "PR is not merged").

3. **Check artifact completion status**

   Run `openspec status --change "<name>" --json` to check artifact completion.

   Parse the JSON to understand:

   - `schemaName`: The workflow being used
   - `artifacts`: List of artifacts with their status (`done` or other)

   **If any artifacts are not `done`:**

   - Display warning listing incomplete artifacts
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

4. **Complete and finalize tasks.md**

   Read the tasks file, typically `tasks.md`.

   **Before proceeding, apply these fixes unconditionally:**

   - Replace any remaining `YYYY-MM-DD` date placeholders with the actual archive date (format: `YYYY-MM-DD` using today's date).
   - Mark all remaining `- [ ]` items as `- [x]`. The archive is the final post-merge step; no tasks should remain open after this point.

   Write the updated tasks.md back to disk as part of the archive commit — do not leave it with unchecked boxes or unresolved placeholders.

   **If no tasks file exists:** Proceed without this step.

5. **Assess delta spec sync state**

   Check for delta specs at `openspec/changes/<name>/specs/`. If none exist, proceed without sync prompt.

   **If delta specs exist:**

   - Compare each delta spec with its corresponding main spec at `openspec/specs/[capability]/spec.md`
   - Determine what changes would be applied: adds, modifications, removals, or renames
   - Show a combined summary before prompting

   **Prompt options:**

   - If changes are needed: `Sync now (recommended)` or `Archive without syncing`
   - If already synced: `Archive now`, `Sync anyway`, or `Cancel`

   If the user chooses sync, use a task or subagent prompt that syncs the delta specs for `[change-name]` back to `openspec/specs/`. For each file under `openspec/changes/[change-name]/specs/[capability]/spec.md`, apply the changes to the corresponding `openspec/specs/[capability]/spec.md`. Include the analyzed delta summary in that prompt. Proceed to archive regardless of choice.

   **After syncing, fix relative links in every promoted spec:** Replace any references to `design.md` or `tasks.md` (bare filenames or relative paths that no longer resolve from `openspec/specs/[capability]/`) with paths pointing to the archive location: `../../changes/archive/YYYY-MM-DD-<name>/design.md` and `../../changes/archive/YYYY-MM-DD-<name>/tasks.md`. Commit these link fixes as part of the same archive commit.

6. **Perform the archive**

   Create the archive directory if it doesn't exist:

   ```bash
   mkdir -p openspec/changes/archive
   ```

   Generate target name using the current date: `YYYY-MM-DD-<change-name>`.

   **Check if target already exists:**

   - If yes: Fail with an error and suggest renaming the existing archive or using a different date
   - If no: Move the change directory to the archive

   ```bash
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

   **Single-commit rule:** After the move, stage both the new archive path and the deletion of the original path together before committing. Use `git add openspec/changes/archive/YYYY-MM-DD-<name>` and `git rm -r openspec/changes/<name>` (or equivalent) so that the copy and the delete land in **one commit**. Never commit the copy first and the delete separately — this leaves the repository in a split state between commits.

7. **Remove the worktree and prune the merged local branch**

   After the PR is merged and the change has been archived, clean up the dedicated worktree and local git state. Do this from the primary checkout, not from inside the worktree being removed.

   - Remove the change's dedicated worktree:

     ```bash
     git worktree remove .worktrees/<name>
     ```

   - Refresh remote-tracking refs:

     ```bash
     git fetch --prune
     ```

   - Delete the merged local feature branch with:

     ```bash
     git branch -d <feature-branch>
     ```

   **Safety rules:**

   - Never use force deletion, `git branch -D` or `git worktree remove --force`, as part of the normal archive flow
   - If the branch is not fully merged, warn the user and leave the worktree and branch in place
   - If the feature branch name cannot be determined reliably, tell the user cleanup is still required and show the commands instead of guessing

8. **Display summary**

   Show archive completion summary including:

   - Change name
   - Schema that was used
   - Archive location
   - Whether specs were synced, if applicable
   - Whether local branch cleanup was completed or skipped
   - Any warnings about incomplete artifacts or tasks

## Output On Success

```text
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced to main specs (or "No delta specs" or "Sync skipped")
**Worktree cleanup:** ✓ Removed .worktrees/<name> and pruned the merged local branch (or "Skipped: branch not identified" / "Skipped: branch not merged")

All artifacts complete. All tasks complete.
```

## Guardrails

- Always prompt for change selection if not provided
- **A change can only be archived if the associated Pull Request is merged, all CI checks have passed, and all review comments have been addressed.**
- Use artifact graph, `openspec status --json`, for completion checking
- Do not block archive on warnings; inform and confirm instead
- Preserve `.openspec.yaml` when moving to archive because it moves with the directory
- Show a clear summary of what happened
- If sync is requested, use an inline subagent to apply delta specs to `openspec/specs/`
- If delta specs exist, always run the sync assessment and show the combined summary before prompting
- After a successful archive, remove the change's dedicated worktree and prune only merged local branches and stale remote-tracking refs; do not force-remove the worktree or force-delete branches
- The archive move (copy to new location + deletion of original) must always be a single atomic git commit — never two separate commits
