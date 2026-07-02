## ADDED Requirements

### Requirement: Linked issue marked in-progress when working branch is created
When the change is issue-driven (a GitHub issue number is recorded in the proposal), the agent SHALL update the linked issue and its associated GitHub Project item to reflect that work has begun, immediately after the working branch is pushed to remote.

#### Scenario: Issue label applied on branch creation
- **WHEN** the working branch is created and pushed for an issue-driven change
- **THEN** the agent runs `gh issue edit #N --add-label "in-progress"` on the linked issue

#### Scenario: Project item moved to In Progress column
- **WHEN** the working branch is created and pushed for an issue-driven change
- **THEN** the agent discovers the GitHub Project linked to the repo, finds the project item for the issue, resolves the status field option whose name semantically matches "In Progress", and moves the item to that column via `gh project item-edit`

#### Scenario: No linked issue — lifecycle hooks are skipped
- **WHEN** the change has no associated GitHub issue number
- **THEN** the agent skips all lifecycle label and project-item updates without error

#### Scenario: Project item not found — warn and continue
- **WHEN** the issue exists but is not present in any GitHub Project linked to the repo
- **THEN** the agent adds the `in-progress` label to the issue, logs a warning that no project item was found, and continues without failing

#### Scenario: Status column not matched — warn and continue
- **WHEN** a project item exists but the project has no status option semantically matching "In Progress"
- **THEN** the agent adds the `in-progress` label to the issue, logs a warning that the column could not be matched, and continues without failing

#### Scenario: Missing GitHub project OAuth scope — clear error
- **WHEN** the `gh` token lacks the `project` scope and the project item edit command fails
- **THEN** the agent surfaces a clear message instructing the user to run `gh auth refresh -s project` and skips the project-item update (issue label update still proceeds)

---

### Requirement: Linked issue updated when PR is opened
When a PR is opened for an issue-driven change, the agent SHALL transition the linked issue and project item to reflect the work is in review.

#### Scenario: Issue labels transitioned on PR open
- **WHEN** the PR is opened for an issue-driven change
- **THEN** the agent runs `gh issue edit #N --add-label "in-review" --remove-label "in-progress"` on the linked issue

#### Scenario: Project item moved to In Review column on PR open
- **WHEN** the PR is opened for an issue-driven change
- **THEN** the agent moves the project item to the status column semantically matching "In Review" (or "Review") via `gh project item-edit`

#### Scenario: PR body includes issue linkage
- **WHEN** the PR is opened for an issue-driven change
- **THEN** the PR body includes `Closes #N` for each linked issue number, causing GitHub to auto-close the issue when the PR merges

---

### Requirement: Linked issue closed and project item completed on PR merge
When the PR merges, GitHub SHALL auto-close the linked issue via the `Closes #N` reference in the PR body, and the project item SHALL reflect completion.

#### Scenario: Issue auto-closes on merge
- **WHEN** the PR containing `Closes #N` merges to the default branch
- **THEN** GitHub automatically closes issue #N

#### Scenario: Project item moves to Done on issue close
- **WHEN** issue #N is closed (by merge or manually)
- **THEN** GitHub Projects automatically moves the project item to the "Done" equivalent column (standard GitHub Projects behavior when issues are closed)
