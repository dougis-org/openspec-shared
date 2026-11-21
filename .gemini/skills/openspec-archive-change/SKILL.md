---
name: openspec-archive-change
description: Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.1"
  generatedBy: "1.2.0"
---

# Archive Change

Archive a completed change: sync specs, archive in one commit, publish via a doc PR, clean up.

## Input

Optional change name. If omitted, infer from context; if vague or ambiguous you MUST prompt (see step 1).

## Steps

1. **Select the change.** If no name was provided, run `openspec list --json` and use the **AskUserQuestion tool** to let the user pick among active (not archived) changes, showing each schema. Never guess or auto-select.

2. **Verify the PR.** Find the change's PR (git history or `gh pr list`). It MUST be merged, all required CI checks passed, and all review comments (including AI agents') addressed and resolved. If any condition fails, do NOT archive; tell the user what is outstanding ("CI checks failed", "Open review comments exist", "PR is not merged").

3. **Check completeness.** `openspec status --change "<name>" --json`. If any artifact is not `done`, warn and confirm with the user before continuing (skip the question when all are `done`).

4. **Finalize `tasks.md`** (skip if absent): replace remaining `YYYY-MM-DD` placeholders with today's date and mark every remaining `- [ ]` as `- [x]`. Write it back as part of the archive commit.

5. **Sync delta specs** (skip if `openspec/changes/<name>/specs/` is absent). Compare each delta with `openspec/specs/<capability>/spec.md` and work out the adds, modifications, removals and renames.

   - **Clean delta** (applies without conflict): sync without asking, and include the summary in the final output.
   - **Conflicts, or already synced:** show the combined summary and ask: `Sync now (recommended)` / `Archive without syncing` (changes needed), or `Archive now` / `Sync anyway` / `Cancel` (already synced).

   To sync, use an inline subagent that applies each `openspec/changes/<name>/specs/<capability>/spec.md` to the matching main spec, given the delta summary. Then fix relative links in every promoted spec: references to `design.md` / `tasks.md` become `../../changes/archive/YYYY-MM-DD-<name>/design.md` and `.../tasks.md`. Commit these with the archive commit.

6. **Archive in a single commit.**

   ```bash
   mkdir -p openspec/changes/archive
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   git add openspec/changes/archive/YYYY-MM-DD-<name> openspec/specs
   git rm -r openspec/changes/<name>
   ```

   Fail with an error if the target already exists (suggest renaming or another date). The new path and the deletion MUST land in one commit, never two. `.openspec.yaml` moves with the directory.

7. **Publish via doc-branch PR** (never push directly to the default branch). Put the commit on `doc/archive-YYYY-MM-DD-<name>`, `git push -u origin doc/archive-YYYY-MM-DD-<name>`, open a PR titled `docs: archive <name> (YYYY-MM-DD)`, run `gh pr merge <DOC-PR-URL> --auto --merge` (never `--admin`), and monitor it with the apply skill's PR triage loop until merged. The same CI definition of done applies.

8. **Clean up** from the primary checkout, after both PRs are merged: `git worktree remove .worktrees/<name>`, `git fetch --prune`, `git branch -d <feature-branch> doc/archive-YYYY-MM-DD-<name>`. Never use `git branch -D` or `git worktree remove --force`. If a branch is not fully merged or the feature branch name cannot be determined reliably, warn, leave things in place, and show the commands instead of guessing.

9. **Summarize:** change, schema, archive location, specs synced or not (and why), cleanup done or skipped, any warnings.

```text
## Archive Complete
**Change:** <name> (schema: <schema>)
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced (or "No delta specs" / "Sync skipped")
**Cleanup:** ✓ Removed .worktrees/<name>, pruned merged branches
```

## Guardrails

- Archive only when the PR is merged, required CI passed, and comments are resolved.
- Ask only when there is a real decision: change selection, incomplete artifacts, sync conflicts.
- The archive move is always one atomic commit, and publishing is always via a doc PR.
