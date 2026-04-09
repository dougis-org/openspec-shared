## GitHub Issues

<!-- None currently linked. -->

## Why

- Problem statement: [README.md](README.md) still documents a Copilot-centric onboarding flow with manual symlink steps, while this repository already contains separate integration surfaces for Codex, Claude, Gemini, and GitHub Copilot.
- Why now: downstream repositories need a reliable, low-friction setup path that matches the actual shared repo structure and avoids repeated manual linking work.
- Business/user impact: contributors can bootstrap the shared OpenSpec workflow consistently across supported agents, reduce setup drift, and refresh downstream repos after submodule updates with one documented flow.

## Problem Space

- Current behavior: onboarding is effectively a manual README recipe that adds the submodule, creates a few symlinks, and assumes `.github/skills/` as the main consumer surface.
- Desired behavior: the shared repo should document supported agent surfaces clearly and provide a bootstrap flow that, after the initial submodule add, can initialize or update the submodule and link all required shared assets into an existing repo automatically.
- Constraints:
  - Keep the two-step adoption model so downstream repos are not forced through extra submodule churn during normal setup.
  - Use symlinks by default so downstream repos consume shared content directly.
  - Provide a copy fallback for environments where symlinks are unavailable or undesirable.
  - Limit the default support contract to proven agent surfaces.
- Assumptions:
  - Downstream repos will continue vendoring this repo as a submodule at `.github/openspec-shared`.
  - Supported default agent surfaces are `.codex/`, `.claude/`, `.gemini/`, and `.github/`.
  - The initial `git submodule add` remains a manual step.
- Edge cases considered:
  - Re-running onboarding in a repo that already contains some links.
  - Refreshing links after bumping the submodule commit.
  - Falling back to copy mode instead of symlinks.
  - Missing parent directories in the consuming repo.

## Scope

### In Scope

- Rewrite onboarding documentation to describe supported agent surfaces and the new two-step setup flow.
- Add a bootstrap script that initializes or updates the shared submodule and links shared assets into an existing repo.
- Define default symlink behavior and optional copy behavior.
- Document `.agent/` as experimental or internal-only rather than part of the default supported contract.

### Out of Scope

- Implementing a one-step external installer that adds the submodule from scratch.
- Refactoring the content of existing agent prompts or skills beyond what is needed to document and wire them.
- Promoting `.agent/` to a default supported public integration target.

## What Changes

- Add a dedicated onboarding/bootstrap script for consuming repositories that:
  - initializes or updates `.github/openspec-shared` after it has been added,
  - creates required directories,
  - links shared templates, config, init script, and supported agent assets,
  - supports copy mode as a fallback.
- Update [README.md](README.md) to describe:
  - the supported agent surfaces,
  - the two-step setup flow,
  - the default symlink strategy,
  - the copy fallback,
  - how to refresh a downstream repo after bumping the submodule.
- Clarify that `.agent/` exists in the shared repo but is not part of the default supported onboarding path.

## Capabilities

### New Capabilities

- `multi-agent-onboarding`: bootstrap and document OpenSpec onboarding for Codex, Claude, Gemini, and GitHub Copilot in downstream repositories using shared assets from this repo.

### Modified Capabilities

<!-- None. No existing canonical specs are present in openspec/specs/. -->

## Impact

- Affected code: [README.md](README.md), new onboarding/bootstrap script, and related setup paths in consuming repositories.
- Affected systems: downstream repos that vendor `.github/openspec-shared` and need agent-facing links under `.codex/`, `.claude/`, `.gemini/`, `.github/`, `openspec/`, and `scripts/`.
- Dependencies: `git`, submodule support, standard shell tools, and symlink support unless copy mode is selected.

## Risks

- Risk: the bootstrap script may conflict with downstream files created manually.
  - Impact: broken setup or uncertainty about rerunning onboarding safely.
  - Mitigation: make the script idempotent, detect existing files and links, and fail clearly unless replacement is explicit.
- Risk: documenting unsupported surfaces as supported could create commitments the repo cannot honor.
  - Impact: adopters rely on behavior that is not backed by a real runtime.
  - Mitigation: keep `.agent/` explicitly experimental and out of the default onboarding path.
- Risk: copy mode can drift from the shared source if users expect automatic updates.
  - Impact: downstream repos silently diverge from the shared repo.
  - Mitigation: document copy mode as a fallback with explicit refresh expectations.

## Open Questions

- No unresolved questions for proposal approval. The working assumptions are: two-step setup, symlinks by default, copy fallback, and `.agent/` excluded from default support.

## Non-Goals

- Replacing the initial manual submodule add step.
- Shipping an external package-manager-based installer.
- Reworking every agent asset format in this change.

## Change Control

If scope changes after proposal approval, update `proposal.md`, `design.md`,
`specs/**/*.md`, and `tasks.md` before implementation starts.

Proposal approval required before proceeding to design, specs, tasks, or apply.
