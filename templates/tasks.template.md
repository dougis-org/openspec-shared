## Execution

- [ ] Create feature branch: `<feature-branch-name>`
- [ ] Implement sub-tasks in small, testable increments
- [ ] Review for duplication and unnecessary complexity
- [ ] Confirm acceptance criteria are covered

## Validation

- [ ] Run unit/integration tests
- [ ] Run E2E tests (if applicable)
- [ ] Run type checks
- [ ] Run build
- [ ] Run security/code quality checks required by project standards

Verification requirements (all must pass before PR):

- **Unit tests** — run the project's unit test suite; all tests must pass
- **Integration tests** — run the project's integration test suite; all tests must pass
- **Regression / E2E tests** — run the project's end-to-end or regression test suite; all tests must pass
- **Build** — run the project's build script; build must succeed with no errors

Use the project's documented commands for each of the above (see project README or CLAUDE.md / AGENTS.md).

## PR and Merge

- [ ] Open PR from feature branch
- [ ] Wait for Agent reviews and CI checks
- [ ] Resolve all review comments
- [ ] Resolve all blocking checks (tests, duplication, quality, security)
- [ ] Enable auto-merge when all required checks are green

Ownership metadata:

- Implementer:
- Reviewer(s):
- Required approvals:

Blocking resolution flow:

- CI failure -> fix -> re-run checks
- Security finding -> remediate -> re-scan
- Review blocker -> address comments or escalate after defined timeout

## Post-Merge

- [ ] Prune local feature branch
- [ ] Update repository documentation impacted by the change
- [ ] Sync approved spec deltas into `openspec/specs/` (global spec)
- [ ] Archive the change under `openspec/changes/archive/`
- [ ] Confirm default branch contains final merged artifacts
