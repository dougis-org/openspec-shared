---
name: pr-reviewer
description: Own a pull request to merge — fix build/test failures first, then address all PR comments, then resolve any remaining required checks, event-driven until the PR is merged.
license: MIT
metadata:
  author: ai-agent-setup
  version: "3.0"
---

# PR Reviewer Skill

Take ownership of a pull request and drive it to merge, in strict priority order: (1) build and tests green, (2) every PR comment addressed and its thread resolved, (3) remaining required checks (coverage, lint, security, etc.). Never hand off and walk away.

This is the standalone form of the PR triage loop in `skills/openspec-apply-change`; keep the two consistent.

## Input

- **PR reference** (number, branch, or URL); infer from `git rev-parse --abbrev-ref HEAD` if omitted.
- **Auto-resolve** (default `true`): resolve addressed threads via GraphQL.

## Steps

1. **Gather context** in one pass:

   ```bash
   gh pr view <ref> --json number,headRefName,baseRefName,state,mergeable,mergeStateStatus
   gh pr checks <number> --required --json name,bucket,link
   gh api graphql -f query='{ repository(owner:"<o>", name:"<r>") { pullRequest(number:<n>) { reviewThreads(first:100) { pageInfo { hasNextPage endCursor } nodes { id isResolved isOutdated path comments(last:1) { nodes { body author { login } } } } } } } }'
   ```

   Paginate only while `hasNextPage` is true; consider only unresolved threads. (`gh pr view --json` has no `reviewThreads` field.)

2. **Priority 1: build and tests.** Run the project's build and full test suite locally (commands from README / CLAUDE.md / AGENTS.md / CI config). Fix root causes; never silence, skip, or comment out tests. Do not start Priority 2 until both are green.

3. **Priority 2: comments.** Classify each unresolved thread. *Actionable*: implement it. *Non-issue*: reply politely with technical evidence. Validate locally, then commit and push once. Resolve every fully addressed thread in one call with aliased mutations (`a:resolveReviewThread(input:{threadId:"<id1>"}){thread{isResolved}} b:resolveReviewThread(...)`), and post replies to non-issue threads. Only resolve threads that are genuinely addressed.

4. **Priority 3: remaining required checks.** Read failure logs (`gh run view <run-id> --log-failed`), fix in code (coverage, lint, complexity, security), validate locally, push in one commit. Ignore non-required checks unless the user asks. Never waive, lower, skip, or disable a check; if a gate looks wrong, ask the user.

5. **Watch until merged, event-driven.** No fixed-interval polling: run `gh pr checks <number> --required --watch --fail-fast`, which returns on the first failure or when all required checks finish. On return, re-assess by priority:

   | Condition | Action |
   |---|---|
   | build/test failure on CI | Step 2 |
   | new unresolved threads | Step 3 |
   | new failing required check | Step 4 |
   | all required checks pass, no unresolved threads | enable auto-merge if not set: `gh pr merge <number> --auto --merge` |
   | `mergeStateStatus: BLOCKED` with nothing failing | tell the user a required human approval is pending, then keep watching |
   | `state: MERGED` | done: report success |
   | `state: CLOSED` | notify the user and stop |

## Guardrails

- **Iterate at most twice.** After two fix-and-push iterations the third assessment is final: if failing tests, open threads, or blocking checks remain, stop and escalate to the user with the remaining items. Never start a fourth iteration.
- Priorities are strict: no comment work until build and tests are green; no secondary check work until threads are resolved.
- Never say "the PR will merge when CI passes" and stop; keep watching until `MERGED` or `CLOSED`.
- Batch related fixes into one commit per iteration. Be polite and constructive with reviewers.
- Never resolve a thread to make the count look clean. Never force-merge or use `--admin`.
