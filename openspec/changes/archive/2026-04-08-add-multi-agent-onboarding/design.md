## Context

- Relevant architecture:
  - This repo is the shared source of truth for OpenSpec templates, config, and agent-facing workflow assets.
  - Downstream repos vendor it as a submodule at `.github/openspec-shared`.
  - The shared repo currently exposes agent-specific surfaces at `.codex/`, `.claude/`, `.gemini/`, `.github/`, and `.agent/`.
- Dependencies:
  - `git` with submodule support
  - POSIX shell
  - standard filesystem tools (`mkdir`, `ln`, `cp`, `rm`, `test`)
- Interfaces/contracts touched:
  - [README.md](README.md) onboarding instructions
  - new bootstrap/onboarding script contract
  - downstream repo directory conventions for `.codex/`, `.claude/`, `.gemini/`, `.github/`, `openspec/`, and `scripts/`

## Goals / Non-Goals

### Goals

- Define a two-step onboarding flow:
  - Step 1: user adds the submodule manually
  - Step 2: shared bootstrap script initializes or updates the submodule and wires the repo
- Make symlinks the default integration mode.
- Provide a copy fallback for environments where symlinks are unsuitable.
- Keep the documented support contract limited to Codex, Claude, Gemini, and GitHub Copilot.
- Make rerunning onboarding safe for downstream repos after submodule bumps.

### Non-Goals

- Automating the first-time `git submodule add` from outside the repo.
- Making `.agent/` part of the default support surface.
- Changing prompt or skill semantics beyond setup and documentation.

## Decisions

### Decision 1: Use a two-step onboarding flow

- Chosen: keep `git submodule add ... .github/openspec-shared` as the only manual prerequisite, then run a shared bootstrap script from the vendored submodule.
- Alternatives considered:
  - one-step installer that adds the submodule itself
  - full manual README-only setup
- Rationale:
  - adding the submodule from a script that lives inside the submodule is awkward and brittle
  - the user explicitly prefers the two-step approach to avoid submodule churn
  - once the submodule exists, the shared repo can own the rest of the wiring reliably
- Trade-offs:
  - setup is not a single command from zero
  - the flow is much simpler and more stable after the initial add

### Decision 2: Make symlinks the default, with explicit copy fallback

- Chosen: the bootstrap script creates symlinks by default and supports copy mode via a flag.
- Alternatives considered:
  - copy files only
  - symlinks only with no fallback
- Rationale:
  - symlinks preserve a clear source of truth and make updates cheap
  - some environments or policies make symlinks inconvenient, so copy mode is still necessary
- Trade-offs:
  - symlink handling requires careful path resolution and idempotent replacement logic
  - copy mode introduces drift risk that must be documented

### Decision 3: Support only proven public agent surfaces by default

- Chosen: default onboarding targets `.codex/`, `.claude/`, `.gemini/`, and `.github/`; `.agent/` remains experimental and undocumented for default setup.
- Alternatives considered:
  - include `.agent/` by default
  - exclude any non-Copilot surface until each has bespoke documentation
- Rationale:
  - the repo contents already indicate intended support for the four named surfaces
  - `.agent/` appears to be a stored format but not a clearly adopted runtime contract
- Trade-offs:
  - experimental consumers of `.agent/` need an opt-in path later
  - the public support contract stays honest

### Decision 4: Make the bootstrap script idempotent and refresh-oriented

- Chosen: the script should create missing directories, initialize or update the submodule, create or refresh links, and fail clearly when replacement would be destructive unless explicitly requested.
- Alternatives considered:
  - one-time setup script only
  - force replacement without checks
- Rationale:
  - downstream repos need to rerun onboarding after submodule bumps
  - idempotence reduces fear around rerunning setup
- Trade-offs:
  - more logic in the shell script
  - much safer repeated usage

## Proposal to Design Mapping

- Proposal element: bootstrap script initializes or updates the shared submodule after manual add
  - Design decision: Decision 1 and Decision 4
  - Validation approach: rerun script in a repo with an existing `.github/openspec-shared` and confirm no destructive drift
- Proposal element: symlinks by default, copy as fallback
  - Design decision: Decision 2
  - Validation approach: verify both default mode and `--copy` produce the expected target tree
- Proposal element: support Codex, Claude, Gemini, and GitHub Copilot
  - Design decision: Decision 3
  - Validation approach: verify links exist for all four default surfaces and `.agent/` is not linked by default
- Proposal element: README reflects the real repo structure
  - Design decision: Decisions 1 through 4
  - Validation approach: confirm README setup steps match script behavior and supported surfaces

## Functional Requirements Mapping

- Requirement: downstream repos can run a shared bootstrap after adding the submodule
  - Design element: bootstrap entrypoint under the shared repo plus README instructions
  - Acceptance criteria reference: `multi-agent-onboarding` / Bootstrap existing repo with symlinks
  - Testability notes: run script from a fixture repo and inspect resulting filesystem layout
- Requirement: the script supports copy fallback
  - Design element: explicit flag-driven link strategy
  - Acceptance criteria reference: `multi-agent-onboarding` / Bootstrap existing repo with copied assets
  - Testability notes: run in copy mode and confirm files/directories exist as copies rather than symlinks
- Requirement: default setup excludes `.agent/`
  - Design element: supported-surface allowlist
  - Acceptance criteria reference: `multi-agent-onboarding` / Default onboarding excludes experimental surfaces
  - Testability notes: inspect output tree after default run

## Non-Functional Requirements Mapping

- Requirement category: reliability
  - Requirement: rerunning onboarding should be safe and predictable
  - Design element: idempotent create-or-refresh behavior with clear replacement rules
  - Acceptance criteria reference: non-functional reliability scenario
  - Testability notes: run bootstrap twice and compare resulting tree
- Requirement category: operability
  - Requirement: downstream users must understand how to refresh setup after submodule updates
  - Design element: README refresh section aligned with script behavior
  - Acceptance criteria reference: documentation-related acceptance scenario
  - Testability notes: follow README from a clean fixture repo
- Requirement category: security
  - Requirement: bootstrap must not silently overwrite unrelated repo files
  - Design element: explicit checks before replacement
  - Acceptance criteria reference: non-functional security scenario
  - Testability notes: seed conflicting files and verify the script fails clearly unless forced

## Risks / Trade-offs

- Risk/trade-off: relative symlink targets are easy to get wrong across nested directories
  - Impact: broken downstream links
  - Mitigation: centralize target mapping and validate created paths during local testing
- Risk/trade-off: copy mode may be mistaken for a live linked setup
  - Impact: downstream drift after updates
  - Mitigation: document copy mode as fallback only and add explicit messaging in script output
- Risk/trade-off: supporting multiple agent surfaces increases maintenance burden
  - Impact: README and bootstrap can fall out of sync with repo contents again
  - Mitigation: define a single support matrix in docs and keep bootstrap mappings close to the documented list

## Rollback / Mitigation

- Rollback trigger: onboarding script or README changes prove confusing or produce incorrect links in fixture repos
- Rollback steps:
  - revert the bootstrap script changes
  - revert README changes
  - keep the previous manual onboarding instructions temporarily if needed
- Data migration considerations:
  - no persistent data migration
  - downstream repos may need to remove incorrect links created by a faulty script version
- Verification after rollback:
  - confirm README no longer references the removed flow
  - confirm downstream setup can still be completed manually

## Operational Blocking Policy

- If CI checks fail: fix the script or docs issue, rerun local validation, and push only after the failing checks are reproducible and resolved
- If security checks fail: treat filesystem replacement behavior as blocking, harden the script, and rerun validation before proceeding
- If required reviews are blocked/stale: keep the branch current, respond to review comments, and refresh PR status rather than bypassing review
- Escalation path and timeout: if bootstrap behavior is ambiguous across agent surfaces, stop and clarify the support contract before merge

## Open Questions

- None at design time beyond normal implementation detail choices such as the final script path and flag names.
