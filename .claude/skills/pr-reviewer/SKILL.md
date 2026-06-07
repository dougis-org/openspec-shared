---
name: pr-reviewer
description: Own a pull request to merge — fix build/test failures first, then address all PR comments, then resolve any remaining checks. Monitors every 30 seconds until the PR is merged.
license: MIT
metadata:
  author: ai-agent-setup
  version: "2.0"
---

# PR Reviewer Skill

Take full ownership of a pull request and drive it to merge. Work through
problems in strict priority order: the build and all tests must be green first,
then every PR comment must be addressed and resolved, and only then are
secondary checks (coverage, lint, etc.) tackled. Monitor continuously — every
30 seconds — until the PR is actually merged. Never hand off and walk away.

---

## Input

- **PR Reference / ID**: The identifier, branch name, or URL of the target
  pull request. Attempt to infer from the local branch using
  `git rev-parse --abbrev-ref HEAD` if not supplied.
- **Auto-Resolve Mode**: Whether to resolve addressed comment threads via
  GraphQL mutations (defaults to `true`).

---

## Priority Order (strict — do not skip ahead)

```
Priority 1 ── Build & all tests must pass
Priority 2 ── All PR comments addressed and threads resolved
Priority 3 ── Remaining checks (coverage, lint, complexity, etc.)
```

Work on Priority 1 first. Do not move to Priority 2 until the local build and
full test suite pass cleanly. Do not move to Priority 3 until every open
comment thread is resolved.

---

## Steps

### Step 1 — Gather PR context

Collect everything needed before touching any code:

```bash
# Identify the PR
gh pr view <ref> --json number,title,headRefName,baseRefName,state,\
mergeable,mergeStateStatus,commits,reviewThreads,statusCheckRollup

# List all open comment threads
gh api repos/<owner>/<repo>/pulls/<number>/comments \
  --jq '.[] | {id,path,line,body,user:.user.login}'

# List check / CI status
gh pr checks <number>
```

Record:
- Latest commit SHA and branch name
- Every open review thread (id, path, line, body)
- Every CI check name and status (pass / fail / pending)

---

### Step 2 — Priority 1: Fix the build and all tests

**This is the unconditional first step. Do not skip it even if the PR has
comments waiting.**

Run the build and full test suite locally:

```bash
npm run build          # or equivalent for the project
npm test               # or the project's full test command
```

For each failure:
1. Read the error output carefully — trace to the root cause in source code.
2. Fix the code. Do not silence tests or skip failing cases.
3. Re-run the relevant tests to confirm the fix before running the full suite.
4. Once the full suite is green locally, commit and push:

```bash
git add <changed files>
git commit -m "fix: resolve build/test failures"
git push
```

Repeat until `npm run build` and the full test suite both exit cleanly with
zero failures. **Do not proceed to Step 3 until this is true.**

---

### Step 3 — Priority 2: Address all PR comments

Read every open review thread collected in Step 1. For each one, classify it:

- **Actionable** — the suggestion is valid and requires a code or doc change.
- **Non-issue / Clarification** — based on a misunderstanding, out of scope,
  or a deliberate design decision that can be justified with evidence.

**For actionable comments:**
- Implement the change.
- Run the build and full test suite again locally to confirm no regressions.

**For non-issues:**
- Draft a professional, polite reply citing specific technical evidence or
  the relevant architectural/design rationale. Do not dismiss without reason.

Once all changes are ready, commit and push them together in a single commit:

```bash
git add <changed files>
git commit -m "fix: address PR review comments"
git push
```

Wait **30 seconds** after the push, then resolve every thread that has been
fully addressed using GraphQL mutations:

```bash
gh api graphql -f query='mutation {
  resolveReviewThread(input: {threadId: "<thread-id>"}) {
    thread { isResolved }
  }
}'
```

Post replies to non-issue threads at the same time. Only resolve threads where
the concern has genuinely been addressed — never resolve prematurely.

Re-read the PR after resolving to confirm no threads remain open. If new
comments have arrived since Step 1, classify and address them now. Repeat
until zero open threads remain.

**Do not proceed to Step 4 until all threads are resolved.**

---

### Step 4 — Priority 3: Resolve remaining checks

With the build, tests, and comments all clean, assess any remaining failing
checks:

```bash
gh pr checks <number>
```

For each failing check:
1. Determine whether it is **blocking** (required for merge) or
   **informational** (non-blocking). Only work on blocking checks.
2. Read the check's output / logs to understand the root cause.
3. Fix the code (e.g., add missing test coverage, resolve lint errors,
   reduce complexity).
4. Run the affected check locally to confirm the fix before pushing.
5. Commit and push fixes in a single clean commit:

```bash
git commit -m "fix: resolve blocking CI check failures"
git push
```

Do not spend time on non-blocking / informational checks unless the user
explicitly requests it.

---

### Step 5 — Monitor until merged (30-second loop)

The agent owns this PR until it is merged. Poll every 30 seconds:

```bash
gh pr view <number> --json state,mergeStateStatus,reviewThreads,\
statusCheckRollup
```

On each poll, evaluate in priority order:

| Condition | Action |
|-----------|--------|
| New open comment threads | Go back to Step 3 immediately |
| Build or test failure on CI | Go back to Step 2 immediately |
| New blocking check failure | Go back to Step 4 |
| `state: MERGED` | Done — report success |
| `mergeStateStatus: BLOCKED` (no failing checks, no open threads) | Report to user: PR is waiting on a required human approval; continue polling |
| All checks passing, no open threads | If auto-merge is not already set: `gh pr merge <number> --auto --squash` |

Continue polling until `state` is `MERGED`. Never stop and say "the PR will
merge when CI passes" — keep monitoring and act on whatever comes up.

---

## Guardrails

- **Build and tests are always first** — no PR comment work starts until the
  local build and full test suite are green.
- **Comments are second** — no secondary check work starts until all comment
  threads are resolved.
- **Never hand off** — do not tell the user "the PR will merge when CI passes"
  or similar. Keep polling and acting until `state: MERGED`.
- **30-second polling** — check PR status every 30 seconds throughout Step 5.
  If new comments arrive between polls, address them immediately.
- **Never skip or silence tests** — do not comment out, mark as pending, or
  otherwise suppress a failing test to make the suite pass. Fix the root cause.
- **Polite & constructive** — always reply to reviewers with an encouraging,
  professional tone. Ground "non-issue" justifications in technical evidence.
- **Consolidated commits** — batch related fixes into single clean commits to
  minimise CI re-run overhead. Avoid one commit per comment.
- **Idempotent thread resolution** — only resolve a thread after its concern
  has been fully addressed. Never resolve a thread to make the count look clean.
- **Do not fix non-blocking checks** — unless the user explicitly requests it,
  focus only on checks that are required for merge.
