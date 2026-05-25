---
name: openspec-review-code
description: Review staged and unstaged changes before committing to ensure code quality, minimize complexity, and eliminate duplication.
license: MIT
compatibility: Requires git.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
---

# Code Review

Review code changes prior to committing to ensure high quality, avoid unnecessary complexity, and eliminate duplication.

## Input

No input is required. The skill will automatically inspect the repository's current changes.

## Steps

1. **Review Changes**
   Run the following commands to see all changes introduced by the feature branch:
   ```bash
   git diff <default-branch>...HEAD
   git diff HEAD
   ```

2. **Analyze for Issues**
   Review the diff with the following goals. **Only report issues you are confident about**:
   - **Reduce complexity**: Identify logic or structure that is needlessly complex and suggest a simpler equivalent.
   - **Eliminate duplication**: Spot repeated logic within the diff, AND actively search the existing codebase to ensure the new code isn't duplicating existing functions. If existing tooling can be extended instead of writing from scratch, suggest doing so.
   - **Improve completeness & quality**: Flag naming that is unclear, logic that is ambiguous, or anything likely to confuse a future reader.

   *Do not suggest adding comments, docstrings, type annotations, or test coverage for code that is not part of the diff. Do not propose speculative abstractions.*

3. **Report Findings**
   Return a structured review report in this exact format (write "None" if no findings):

   ```
   ## Pre-Commit Review Report

   ### Complexity Issues
   - <file>:<line> — <description> — Suggested fix: <concise fix>

   ### Duplication Issues
   - <file>:<line> — <description> — Suggested fix: <concise fix>

   ### Quality Issues
   - <file>:<line> — <description> — Suggested fix: <concise fix>
   ```

4. **Actionable Fixes**
   If acting as a sub-agent, the calling agent will read this report and apply fixes that are clearly correct and within scope before committing.
