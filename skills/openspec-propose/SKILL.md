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

When ready to implement, run `/opsx:apply`.

Before starting implementation work, check out the default branch and pull the latest remote changes so the feature branch starts from current state.

## Input

The user's request should include either a kebab-case change name or a description of what they want to build.

## Steps

1. **If no clear input is provided, ask what they want to build**

   Use the **AskUserQuestion tool** with an open-ended prompt such as:

   > What change do you want to work on? Describe what you want to build or fix.

   From the description, derive a kebab-case name, for example `add-user-auth`.

   **IMPORTANT:** Do not proceed until the requested change is understood.

2. **Create the change directory**

   ```bash
   openspec new change "<name>"
   ```

   This creates a scaffolded change at `openspec/changes/<name>/` with `.openspec.yaml`.

3. **Get the artifact build order**

   ```bash
   openspec status --change "<name>" --json
   ```

   Parse the JSON to get:

   - `applyRequires`: artifact IDs required before implementation, for example `tasks`
   - `artifacts`: all artifacts with status and dependencies

4. **Create artifacts in sequence until apply-ready**

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

   Continue until all entries in `applyRequires` are complete.

   After creating each artifact:

   - Re-run `openspec status --change "<name>" --json`
   - Check whether every artifact ID in `applyRequires` has status `done`

   If an artifact requires user input because context is unclear, ask for clarification and continue.

5. **Show final status**

   ```bash
   openspec status --change "<name>"
   ```

## Output

After completing all artifacts, summarize:

- Change name and location
- Artifacts created with brief descriptions
- Readiness status: `All artifacts created. Ready for implementation.`
- Prompt: `Before implementation, run git checkout <default-branch> and git pull --ff-only, then run /opsx:apply or ask me to implement to start working on the tasks.`

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
- Verify each artifact file exists after writing before proceeding
