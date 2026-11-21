# Token-efficient change cycle (design)

## Intent
Cut the tokens an agent spends per change (propose → apply → archive) without removing any quality gate. Process rules are currently restated in `config.yaml`, the `tasks.md` template, `openspec-apply-change`, and `USAGE.md`; every change regenerates and re-reads them.

## Goals
- Each rule has exactly one home; other places point to it.
- Same gates: human-approved proposal, BDD/TDD, pre-commit review, auto-merge, atomic archive via doc-branch PR.
- Fewer/cheaper tool calls in the review and PR loops.

## Non-goals / anti-goals
- No change to the artifact graph (`tests.md` stays separate; it aids review).
- No gate dropped or weakened (review still runs before every commit).
- No change that breaks in-flight changes' existing `tasks.md` files.

## Approaches considered
- A. Dedupe only: safest, leaves loop cost.
- **B. A + cheaper loops (chosen).**
- C. B + merge tests into tasks: rejected (user wants `tests.md` for review; breaks in-flight changes).

## Design
1. **Process lives in skills.** `openspec-apply-change` owns implement/PR/merge loop; `openspec-archive-change` owns post-merge. Apply's post-merge step becomes "run `/opsx:archive`" (fixes the direct-push-to-main conflict).
2. **Slim `tasks.md` template** to change-specific content: Preparation (2 git steps), Execution (one checkbox per task, each naming its `tests.md` case), Validation, PR and Merge (open PR with `Closes #N`, enable auto-merge, then "follow apply skill step 10"), Post-Merge ("run /opsx:archive"). Drop duplicated blocks (suggested commands, repeated cleanup, repeated blocking flow). Keep ownership metadata.
3. **Slim `config.yaml` task rules** to ~8 one-line rules that point to the skills; trim design/spec rules that duplicate template headings (required sections stay).
4. **Single traceability home:** the spec Traceability block. Design mapping tables keep proposal→decision only; `tests.md` rule just says "map each case to a task and scenario".
5. **Incremental review:** `openspec-review-code` accepts an optional base SHA; first review diffs against the default branch, later reviews diff `<last-reviewed-sha>..HEAD` plus working tree. Report format unchanged.
6. **Cheaper PR loop:** one GraphQL call returns unresolved threads (latest comment only) and check rollup; check `state`/`mergeStateStatus` first and skip thread/CI work if nothing changed since last poll; paginate only on `hasNextPage`; resolve threads in one batched mutation call.
7. **Cheaper resume:** apply reads `tasks`, `tests`, `specs` by default; `proposal`/`design` only when a task is ambiguous or on first start of a change.
8. **Skill cleanup:** remove sample output blocks and guardrails that repeat steps; fix duplicate step 8 numbering and the duplicated paragraph in `openspec-propose`; add `specs` to its artifact list.
9. **Template duplication:** `schemas/sdd-with-feedback-loop/templates/` is the single copy. `templates/` removal depends on whether `bootstrap.sh`/`update.sh` use it; verify first, otherwise generate it from the schema copy.
10. Update `README.md`/`USAGE.md` to reference rather than restate.

11. **Apply-stage definition of done (tool-agnostic).** The apply stage is complete only when the PR is merged with every required CI check passing, including whatever quality gates the repo defines (static analysis/lint, security scans, test coverage thresholds, build). Rules name the categories, never specific tools or numbers; the repo's own docs (README/CLAUDE.md/AGENTS.md) and CI config are the source of the commands and thresholds. Stated once in the design's rule set and referenced from:
    - `config.yaml` tasks rules (one rule),
    - `tasks.md` template Validation section (run the repo's local equivalents of CI: tests, build, lint/static analysis, security checks, coverage; all must pass before push),
    - apply skill PR loop (a required check failing, including a quality gate or coverage drop, is fixed in code, never waived, lowered or bypassed; apply is not complete until all required checks pass and the PR merges). The change as a whole is done only after the archive stage finishes (spec sync, doc-branch PR merged, local cleanup).
    The agent must not weaken thresholds, skip or disable checks, or mark checks non-required to get green; if a gate looks wrong, pause and ask the user.

## Left to the builder
Exact wording, and the GraphQL query shape. Measure before/after byte counts of the files an agent loads per change and report them.
