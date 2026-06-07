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

Archive a completed change in the experimental workflow.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes. Use the **AskUserQuestion tool** to let the user select.

   Show only active changes (not already archived).
   Include the schema used for each change if available.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check artifact completion status**

   Run `openspec status --change "<name>" --json` to check artifact completion.

   Parse the JSON to understand:
   - `schemaName`: The workflow being used
   - `artifacts`: List of artifacts with their status (`done` or other)

   **If any artifacts are not `done`:**
   - Display warning listing incomplete artifacts
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

3. **Complete and finalize tasks.md**

   Read the tasks file (typically `tasks.md`).

   **Before proceeding, apply these fixes unconditionally:**
   - Replace any remaining `YYYY-MM-DD` date placeholders with the actual archive date (today's date in `YYYY-MM-DD` format).
   - Mark all remaining `- [ ]` items as `- [x]`. The archive is the final post-merge step; no tasks should remain open after this point.

   Write the updated tasks.md back to disk — it will be included in the archive commit. Do not leave it with unchecked boxes or unresolved placeholders.

   **If no tasks file exists:** Proceed without this step.

4. **Assess delta spec sync state**

   Check for delta specs at `openspec/changes/<name>/specs/`. If none exist, proceed without sync prompt.

   **If delta specs exist:**
   - Compare each delta spec with its corresponding main spec at `openspec/specs/<capability>/spec.md`
   - Determine what changes would be applied (adds, modifications, removals, renames)
   - Show a combined summary before prompting

   **Prompt options:**
   - If changes needed: "Sync now (recommended)", "Archive without syncing"
   - If already synced: "Archive now", "Sync anyway", "Cancel"

   If user chooses sync, use Task tool (subagent_type: "general-purpose", prompt: "Use Skill tool to invoke openspec-sync-specs for change '<name>'. Delta spec analysis: <include the analyzed delta spec summary>"). Proceed to archive regardless of choice.

   **After syncing, fix relative links in every promoted spec:** Scan each file just written to `openspec/specs/` and replace any bare `design.md` or `tasks.md` references (and any relative paths that no longer resolve from `openspec/specs/<capability>/`) with archive-relative paths: `../../changes/archive/YYYY-MM-DD-<name>/design.md` and `../../changes/archive/YYYY-MM-DD-<name>/tasks.md`. Include these fixes in the archive commit.

5. **Perform the archive**

   Create the archive directory if it doesn't exist:
   ```bash
   mkdir -p openspec/changes/archive
   ```

   Generate target name using current date: `YYYY-MM-DD-<change-name>`

   **Check if target already exists:**
   - If yes: Fail with error, suggest renaming existing archive or using different date
   - If no: Move the change directory to archive

   ```bash
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

6. **Open a doc-branch PR for the archive**

   Stage and commit all archive and spec changes, then create a `doc/` branch and open a PR — never push directly to the default branch:

   ```bash
   git checkout -b doc/archive-YYYY-MM-DD-<name>
   git add openspec/changes/archive/YYYY-MM-DD-<name>/ openspec/specs/
   git rm -r openspec/changes/<name>/   # stage the deletion
   git commit -m "docs: archive <name> (YYYY-MM-DD)"
   git push -u origin doc/archive-YYYY-MM-DD-<name>
   gh pr create \
     --base <default-branch> \
     --head doc/archive-YYYY-MM-DD-<name> \
     --title "docs: archive <name> (YYYY-MM-DD)" \
     --body "Archives completed change **<name>** and syncs delta specs to main specs."
   gh pr merge <DOC-PR-URL> --auto --merge
   ```

   **IMPORTANT:** Do NOT push directly to the default branch. Always use the PR flow so contributors without direct push access can observe and act on the change.

7. **Display summary**

   Show archive completion summary including:
   - Change name
   - Schema that was used
   - Archive location
   - Doc-branch PR URL
   - Whether specs were synced (if applicable)
   - Note about any warnings (incomplete artifacts/tasks)

**Output On Success**

```
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced to main specs (or "No delta specs" or "Sync skipped")
**Doc PR:** <DOC-PR-URL> (auto-merge enabled)

All artifacts complete. All tasks complete.
```

**Guardrails**
- Always prompt for change selection if not provided
- Use artifact graph (openspec status --json) for completion checking
- Don't block archive on warnings - just inform and confirm
- Preserve .openspec.yaml when moving to archive (it moves with the directory)
- Show clear summary of what happened
- If sync is requested, use openspec-sync-specs approach (agent-driven)
- If delta specs exist, always run the sync assessment and show the combined summary before prompting
- **Never push archive/spec changes directly to the default branch** — always use a `doc/archive-YYYY-MM-DD-<name>` branch with a PR set to auto-merge
