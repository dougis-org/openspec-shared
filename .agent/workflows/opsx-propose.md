---
description: "Propose a new change - create it and generate all artifacts in one step"
---

# Propose Change

Propose a new change and generate all artifacts in one step: `proposal.md` (what/why), `design.md` (how), `specs/**/*.md` (behavior scenarios), `tasks.md` (steps), `tests.md` (test cases). When ready to implement, run `/opsx:apply`.

All work on the change happens in its dedicated git worktree, never the primary checkout, so agents can work on different changes from one clone in parallel.

## Input

A kebab-case change name or a description of what to build, or a GitHub issue reference (bare number, `#N`, issue URL, or `OWNER/REPO#N`) whose issue is fetched and used as the basis.

## Steps

1. **Understand the request**

   - **GitHub issue reference:** `gh issue assign <ref> --me`, then `gh issue view <ref> --json title,body,comments`. Derive the kebab-case name from the title, use title + body as the description, and record the reference for step 2.
   - **Clear description:** use it as the basis; use a given kebab-case name or derive one (e.g. `add-user-auth`). Ask a clarifying question only if the request is ambiguous or missing key details.
   - **No input:** use the **AskUserQuestion tool**: "What change do you want to work on? Describe what you want to build or fix." Do not proceed until the change is understood.

2. **Collect GitHub issue references**

   If one was recorded in step 1, use it. Otherwise ask: "Is this change driven by one or more GitHub issues? Share numbers or URLs (e.g. `#42`, `myorg/repo#7`), or leave blank." Record them for the `## GitHub Issues` section of `proposal.md` so the PR closes them on merge.

3. **Create or reuse the change's worktree**

   From the primary checkout, `git worktree list`. If `.worktrees/<name>` does not exist (explore may have started it):

   ```bash
   git fetch origin
   git worktree add ".worktrees/<name>" -b "<name>" "origin/<default-branch>"
   git push -u origin "<name>"
   ```

   If `.worktrees/` is not already ignored, add it to `.git/info/exclude` (local, untracked) instead of editing the primary checkout, and include a `.gitignore` entry in the change's own PR; then `cd ".worktrees/<name>"`. Run every command and write every file for this change from inside it.

4. **Create the change directory** (inside the worktree): `openspec new change "<name>"` creates `openspec/changes/<name>/` with `.openspec.yaml`.

5. **Get the build order:** `openspec status --change "<name>" --json` once; note `applyRequires` and each artifact's dependencies.

6. **Create artifacts in dependency order until apply-ready**

   Track progress with the todo tool. For each `ready` artifact:

   - `openspec instructions <artifact-id> --change "<name>" --json`; use `context`, `rules`, `template`, `instruction`, `outputPath`, `dependencies`.
   - Read only dependency artifacts that are not already in your context (do not re-read files you just wrote).
   - Write the file from `template`. Treat `context` and `rules` as constraints; never copy them into the file.
   - Verify the file exists, and show `Created <artifact-id>`.

   Continue until every `applyRequires` artifact is done (this includes `tests`). For `tasks.md` and `tests.md`, follow the schema instruction and rules (test-first BDD/TDD, pre-commit review, CI-equivalent validation as part of done) and reference the apply skill for process; do not restate it. If an artifact needs input because context is unclear, ask and continue.

7. **Final status:** `openspec status --change "<name>"`.

## Output

Summarize: change name and location, worktree `.worktrees/<name>`, artifacts created, `All artifacts created. Ready for implementation.`, and `Ready for implementation from .worktrees/<name> — run /opsx:apply or ask me to implement to start working on the tasks.`

## Guardrails

- Create every artifact in `apply.requires`; prefer reasonable decisions that keep momentum, and ask only if context is critically unclear.
- If a change with that name already exists, ask whether to continue it or create a new one.
- Always create or reuse the dedicated worktree before creating the change directory; never work in the primary checkout.
- If this change arrived from an explore session that resolved every open question and the user explicitly said to proceed with the proposal, continue through design, specs, and tasks without a separate approval pause. Otherwise the proposal needs explicit human approval before design/specs/tasks/apply.
