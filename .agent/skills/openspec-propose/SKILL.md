---
name: openspec-propose
description: Propose a new change with all artifacts generated in one step. Use when the user wants to quickly describe what they want to build and get a complete proposal with design, specs, and tasks ready for implementation.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
---

# Propose Change

Propose a new change and generate all artifacts in one step.

This skill creates:

- `proposal.md` for what and why
- `design.md` for how
- `tasks.md` for implementation steps
- `tests.md` for test cases

When ready to implement, run `/opsx:apply`.

All work on this change — the proposal artifact through implementation — happens inside a dedicated git worktree, never in the primary checkout. This is what lets multiple agents work on different changes from the same repo clone at the same time.

## Input

The user's request may include:

- A kebab-case change name or a description of what they want to build
- A GitHub issue reference: a bare number (`123`), `#N`, a full issue URL, or `OWNER/REPO#N` — in which case the issue is fetched and used as the basis for the change

## Steps

1. **Detect GitHub issue reference or ask what to build**

   Check whether the input looks like a GitHub issue reference: a bare integer (`123`), `#N`, a URL containing `/issues/N`, or `OWNER/REPO#N`.

   **If it is a GitHub issue reference:**

   Assign the issue to the current user:
   ```bash
   gh issue assign <ref> --me
   ```

   Fetch the issue:
   ```bash
   gh issue view <ref> --json title,body,comments
   ```
   Use the issue title as the basis for the kebab-case change name (e.g. `add-user-auth`) and the issue title + body as the change description. Record the issue reference — it will be used in Step 2 without prompting.

   **If the input is clear but not a GitHub issue reference:**

   Treat the user's request as the basis for the change. If they already provided a kebab-case change name, use it directly. Otherwise, derive a concise kebab-case change name from their description (for example, `add-user-auth`).

   Use the user's description as the basis for the change description. Do not ask a clarifying question unless the request is still ambiguous or missing key details needed to understand the change.
   **If the input is clear but not a GitHub issue reference:**

   Treat the user's request as the basis for the change. If they already provided a kebab-case change name, use it directly. Otherwise, derive a concise kebab-case change name from their description (for example, `add-user-auth`). Use the user's description as the change description. Do not ask a clarifying question unless the request is still ambiguous or missing key details needed to understand the change.

   **If no clear input is provided:**

   Use the **AskUserQuestion tool** with an open-ended prompt such as:

   > What change do you want to work on? Describe what you want to build or fix.

   From the description, derive a kebab-case name, for example `add-user-auth`.

   **IMPORTANT:** Do not proceed until the requested change is understood.

2. **Collect GitHub issue references** *(unconditional)*

   If a GitHub issue reference was already detected and recorded in Step 1, skip prompting and use that reference directly.

   Otherwise, always ask:

   > Is this change driven by one or more GitHub issues? If so, share the issue numbers or URLs (e.g. `#42`, `myorg/repo#7`). Leave blank if not issue-driven.

   Record any references provided. They will be written into the `## GitHub Issues` section of `proposal.md` so the PR can automatically close them on merge.

3. **Create a dedicated worktree for this change**

   From the primary checkout, check whether a worktree already exists for `<name>` (for example, started during an explore session):

   ```bash
   git worktree list
   ```

   If none exists, fetch the default branch and create one, branching from its current tip:

   ```bash
   git fetch origin
   git worktree add ".worktrees/<name>" -b "<name>" "origin/<default-branch>"
   ```

   Immediately publish the branch so it exists on remote before any work happens on it:

   ```bash
   git push -u origin "<name>"
   ```

   If `.worktrees/` is not already listed in `.gitignore`, add it.

   From this point on, run every command and write every file for this change from inside `.worktrees/<name>` — never from the primary checkout:

   ```bash
   cd ".worktrees/<name>"
   ```

4. **Create the change directory**

   Run this from inside the worktree created in the previous step:

   ```bash
   openspec new change "<name>"
   ```

   This creates a scaffolded change at `openspec/changes/<name>/` with `.openspec.yaml`.

5. **Get the artifact build order**

   ```bash
   openspec status --change "<name>" --json
   ```

   Parse the JSON to get:

   - `applyRequires`: artifact IDs required before implementation, for example `tasks`
   - `artifacts`: all artifacts with status and dependencies

6. **Create artifacts in sequence until apply-ready**

   Use the todo tracking tool to track progress through the artifacts.

   Loop through artifacts in dependency order, starting with artifacts that have no pending dependencies.

   For each artifact that is `ready`:

   - Get instructions:

     ```bash
     openspec instructions <artifact-id> --change "<name>" --json
     ```

   - Use the returned `context`, `rules`, `template`, `instruction`, `outputPath`, and `dependencies`
   - Read any completed dependency files for context
   - Create the artifact file using `template` as the structure
   - Apply `context` and `rules` as constraints, but do not copy them into the file
   - Show brief progress such as `Created [artifact-id]`

   Continue until all entries in `applyRequires` are complete. This includes the `tests` artifact.

   When creating `tasks.md`, include the required pre-PR self-review step from `skills/openspec-apply-change/SKILL.md` as a checklist item before any commit or push steps.

   When creating `tasks.md` and `tests.md`, require a BDD/TDD workflow: define the desired behavior in tests first, then implement against the failing tests. Make that sequence explicit in the task list so implementation cannot begin before the test step is complete.

   After creating each artifact:

   - Re-run `openspec status --change "<name>" --json`
   - Check whether every artifact ID in `applyRequires` has status `done`

   If an artifact requires user input because context is unclear, ask for clarification and continue.

7. **Show final status**

   ```bash
   openspec status --change "<name>"
   ```

## Output

After completing all artifacts, summarize:

- Change name and location
- The worktree the change lives in: `.worktrees/<name>`
- Artifacts created with brief descriptions
- Readiness status: `All artifacts created. Ready for implementation.`
- Prompt: `Ready for implementation from .worktrees/<name> — run /opsx:apply or ask me to implement to start working on the tasks.`

## Artifact Creation Guidelines

- Follow the `instruction` field returned by `openspec instructions` for each artifact type
- Follow the schema requirements for each artifact
- Read dependency artifacts before creating a new one
- Use `template` as the structure for the output file
- Treat `context` and `rules` as constraints for the agent, not as file content
- Do not copy placeholder blocks such as `context`, `rules`, or `project_context` into the artifact

## Guardrails

- Create all artifacts needed for implementation as defined by `apply.requires`
- Always read dependency artifacts before creating a new one
- If context is critically unclear, ask the user, but prefer reasonable decisions that keep momentum
- If a change with that name already exists, ask whether to continue it or create a new one
- Always create or reuse the change's dedicated worktree at `.worktrees/<name>` before creating the change directory, and do all work for the change inside it — never in the primary checkout. Push the branch immediately so it exists on remote.
- If this change arrived from an explore session that already resolved every open question and the user explicitly said to proceed with the proposal, continue straight through design, specs, and tasks without pausing for a separate human approval step. Otherwise, the proposal still requires explicit human approval before design/specs/tasks/apply proceed.
- Verify each artifact file exists after writing before proceeding
