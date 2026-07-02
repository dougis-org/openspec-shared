## ADDED Requirements

### Requirement: Preflight validation of pr-review-toolkit:review-pr at apply start
Before any implementation work begins, the agent SHALL verify that the `pr-review-toolkit:review-pr` skill is available in the current environment.

#### Scenario: Plugin present — apply proceeds
- **WHEN** the agent checks for `pr-review-toolkit:review-pr` at apply start and the skill is available
- **THEN** the agent proceeds to the Preparation phase without interruption

#### Scenario: Plugin absent — halt and prompt
- **WHEN** the agent checks for `pr-review-toolkit:review-pr` at apply start and the skill is not available
- **THEN** the agent halts, informs the user that the plugin is required, provides installation guidance, and does not proceed until the user confirms the plugin is installed

---

### Requirement: Enforced PR review before auto-merge is enabled
After a PR is opened, the agent SHALL run a full review via `pr-review-toolkit:review-pr` as a sub-agent and require all findings to be addressed before enabling auto-merge.

#### Scenario: Review runs after PR is opened
- **WHEN** the PR is opened and 60 seconds have elapsed (to allow CI to start)
- **THEN** the agent spawns a sub-agent running `pr-review-toolkit:review-pr` against the open PR

#### Scenario: Findings addressed before auto-merge
- **WHEN** `pr-review-toolkit:review-pr` returns findings
- **THEN** the agent addresses each finding, commits and pushes fixes, and re-runs the review until zero findings remain, before enabling auto-merge

#### Scenario: Auto-merge enabled only after review gate passes
- **WHEN** `pr-review-toolkit:review-pr` returns zero findings
- **THEN** the agent enables auto-merge via `gh pr merge <PR-URL> --auto --merge`

#### Scenario: Auto-merge is never enabled before review completes
- **WHEN** the PR is opened
- **THEN** the agent does NOT enable auto-merge until the review gate has passed; `gh pr merge --auto` is not called at PR open time

#### Scenario: Review loop stalls — agent reports and waits
- **WHEN** findings persist after three or more review-fix-push iterations with no progress
- **THEN** the agent reports the stall to the user with the remaining findings listed, and waits for human guidance before continuing

---

### Requirement: Monitoring loop continues after auto-merge is enabled
After auto-merge is enabled, the agent SHALL continue monitoring for new review comments and CI failures using the existing iterate-until-merged loop.

#### Scenario: New PR comments after auto-merge enabled
- **WHEN** a reviewer posts a comment after auto-merge is enabled
- **THEN** the agent detects the comment, addresses it, commits and pushes, and continues the monitoring loop

#### Scenario: CI failure after auto-merge enabled
- **WHEN** a required CI check fails after auto-merge is enabled
- **THEN** the agent diagnoses and fixes the failure, commits and pushes, and continues the monitoring loop
