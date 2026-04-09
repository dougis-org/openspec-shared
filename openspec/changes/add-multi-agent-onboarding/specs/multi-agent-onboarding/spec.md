## ADDED Requirements

### Requirement: Bootstrap existing repo with symlinks

The system SHALL provide a shared bootstrap flow that, after `.github/openspec-shared` has already been added to a downstream repository, initializes or updates that submodule and creates symlinks for the supported shared assets.

#### Scenario: Bootstrap a repo that already has the submodule

- **WHEN** a user runs the documented bootstrap command in a downstream repository that already contains `.github/openspec-shared`
- **THEN** the flow initializes or updates the submodule as needed
- **AND** creates the required directories for supported agent surfaces
- **AND** links the shared assets for `.codex/`, `.claude/`, `.gemini/`, `.github/`, `openspec/`, and `scripts/`

#### Scenario: Rerun bootstrap after a submodule bump

- **WHEN** a user reruns the bootstrap flow after updating `.github/openspec-shared` to a newer commit
- **THEN** the flow refreshes the downstream setup without requiring the user to rebuild links manually
- **AND** does not silently overwrite unrelated files

### Requirement: Bootstrap existing repo with copied assets

The system SHALL provide a copy-mode fallback for environments where symlinks are unavailable or undesirable.

#### Scenario: Use copy mode intentionally

- **WHEN** a user runs the bootstrap flow with the documented copy-mode option
- **THEN** the flow materializes the supported shared assets as copied files and directories instead of symlinks
- **AND** the user-visible documentation explains that copied assets must be refreshed manually after shared repo updates

### Requirement: Default onboarding excludes experimental surfaces

The system SHALL limit default onboarding to the supported public agent surfaces and exclude experimental surfaces unless explicitly documented otherwise.

#### Scenario: Default setup targets only supported surfaces

- **WHEN** a user follows the default onboarding flow
- **THEN** the flow wires Codex, Claude, Gemini, and GitHub Copilot assets
- **AND** does not present `.agent/` as part of the default supported integration contract

### Requirement: README documents the two-step setup contract

The system SHALL document the onboarding flow so downstream users understand the initial submodule add step, the bootstrap step, the supported surfaces, and the refresh path.

#### Scenario: README describes first-time setup

- **WHEN** a user reads the onboarding section in [README.md](README.md)
- **THEN** the instructions show that `git submodule add` is the first manual step
- **AND** the instructions show how to run the shared bootstrap flow afterwards
- **AND** the instructions describe symlinks as the default strategy with copy mode as fallback

#### Scenario: README describes refresh workflow

- **WHEN** a user updates `.github/openspec-shared` in a downstream repository
- **THEN** the README explains how to rerun the bootstrap flow to refresh links or copies

## Traceability

- Proposal element -> Requirement:
  - bootstrap script for existing repos -> Bootstrap existing repo with symlinks
  - copy fallback -> Bootstrap existing repo with copied assets
  - supported agent surfaces -> Default onboarding excludes experimental surfaces
  - README rewrite -> README documents the two-step setup contract
- Design decision -> Requirement:
  - Decision 1 and Decision 4 -> Bootstrap existing repo with symlinks
  - Decision 2 -> Bootstrap existing repo with copied assets
  - Decision 3 -> Default onboarding excludes experimental surfaces
  - Decisions 1 through 4 -> README documents the two-step setup contract
- Requirement -> Task(s):
  - Bootstrap existing repo with symlinks -> implement bootstrap script, validate fixture layout, update README
  - Bootstrap existing repo with copied assets -> add copy flag handling, validate copy mode, update README
  - Default onboarding excludes experimental surfaces -> encode support matrix, document `.agent/` status
  - README documents the two-step setup contract -> rewrite onboarding and refresh sections

## Non-Functional Acceptance Criteria

### Requirement: Reliability

#### Scenario: Re-running bootstrap is safe

- **WHEN** a user runs the bootstrap flow more than once in the same downstream repository
- **THEN** the resulting supported asset layout remains correct
- **AND** the flow does not create duplicate nested links or conflicting paths

### Requirement: Security

#### Scenario: Existing conflicting files are handled explicitly

- **WHEN** a downstream repository already contains a non-managed file at a target bootstrap path
- **THEN** the flow fails clearly or requires explicit replacement behavior
- **AND** does not silently replace that file

### Requirement: Operability

#### Scenario: Setup instructions are actionable

- **WHEN** a maintainer follows the README from a clean fixture repository
- **THEN** they can complete first-time setup and refresh setup using only the documented commands
