---
name: code-review
description: |-
  Trigger when a review is asked for without a named lens, or before a commit, push or MR. Prefer /review-correctness, /review-simplicity or /review-tests when the user names that concern, and /qa-loop when they want independent reviewers or repeated rounds.
  Keywords: code review, review my changes, review this diff, check this code, second opinion, look over my MR
---

# Code Review

The general-purpose single review pass, and the **shared contract** the specialised lenses build on. `/review-correctness`, `/review-simplicity` and `/review-tests` all reuse Steps 1, 2 and 4 from here and replace only Step 3.

## Step 1 - Determine the scope

Ask the user what they want reviewed if it's not clear. Common scopes:

| Scope | How to get the diff |
|-------|-------------------|
| Unstaged working changes | `git diff` |
| Staged changes | `git diff --cached` |
| All uncommitted changes | `git diff HEAD` |
| The whole branch | `git diff $(git merge-base HEAD main)...HEAD` |
| Between branches/commits | `git diff <ref1>..<ref2>` |
| A specific commit | `git show <commit>` |
| Specific files | Read the files directly |

If the user says "review my changes" without more context, default to `git diff --cached`. If nothing is staged, ask whether they mean all uncommitted changes or the whole branch.

## Step 2 - Read the full context

For every file in the diff, read the **full file**, not just the hunks. Most real findings are invisible in a hunk: the caller that breaks, the type that no longer fits, the sibling function with the same bug.

Then read what the repo expects of you before judging it:

- Instruction files: `fd -H -i '^(claude|agents)(\.local)?\.md$' <repo-root>` - root, `.claude/`, and per-directory. A convention stated there outranks your own taste.
- Config that encodes style: `.editorconfig`, `.eslintrc`, `.prettierrc`, `Directory.Build.props`, linter settings.

## Step 3 - Analyse the changes

A single pass across every dimension. Each row is deliberately shallow - when the change warrants depth, or the user asks for it, invoke the lens instead.

| Dimension | Check for | Depth lives in |
|-----------|-----------|----------------|
| Correctness | Logic and off-by-one errors, null/empty handling, unhandled failure paths, wrong API contract, concurrency | `/review-correctness` |
| Simplicity | Abstraction with one caller, reinvented stdlib, config for a constant, duplicated logic | `/review-simplicity` |
| Tests | New logic paths with no test, changed behaviour with stale tests, untested edge cases | `/review-tests` |
| Security | Injection (SQL, command, template, XSS), hardcoded secrets, missing authn/authz, unvalidated input at a trust boundary, path traversal | this skill |
| Performance | N+1 queries, unbounded fetch or missing pagination, avoidable allocation in a hot path, accidental O(n²) | this skill |
| Readability | Naming that needs a comment to survive, functions doing several jobs, deep nesting that early returns would flatten, dead or commented-out code | this skill |

⚠️ Never simplify away input validation at a trust boundary, error handling that prevents data loss, security controls, or accessibility basics. A finding that removes one of those is wrong.

## Step 4 - Present findings

This format is the shared contract - the lenses and `/qa-loop` all report in it.

Open with two or three sentences: is this change in good shape, and is anything a blocker? Then findings, grouped by severity:

- **Critical** - must fix before merge. Bugs, security holes, data-loss risk.
- **Warning** - should fix. Error-handling gaps, performance traps, future bugs.
- **Suggestion** - optional. Readability, minor refactors, consistency.

Each finding carries:

1. `path/to/file.ts:42`
2. What is wrong, and why it matters
3. A concrete failure scenario - inputs or state that produce the wrong result. A finding you cannot make fail is a guess; label it as one or drop it.
4. A concrete fix

## Guidelines

- Specific and actionable. "This could be better" is noise; "this `forEach` mutates the input - use `map`" is a review.
- Separate genuine issues from taste. Don't bikeshed style the repo has no convention for.
- Weigh the context. A prototype and a payment path have different bars.
- Say so when the change is fine. Manufacturing findings to look thorough wastes the reader's time and trains them to ignore you.
- Three real findings beat thirty nitpicks. Rank, then cut.
