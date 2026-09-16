---
name: code-review
description: |-
  Trigger to review a diff - "let's do a code review on this", review this PR or MR, a second opinion before merge. Runs the review as independent lens subagents. Prefer /review-correctness, /review-simplicity or /review-tests when the user names one concern.
  Keywords: code review, review this PR, review this MR, review this diff, check this code, second opinion, review my changes
---

# Code Review

The entry point for a review: one pass over a diff by independent lens subagents, merged into a single report.

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
| The whole tree, no diff | Read the tree. An audit, not a review - only `/review-simplicity` and `/review-tests` make sense at this scope |

If the user says "review my changes" without more context, default to `git diff --cached`. If nothing is staged, ask whether they mean all uncommitted changes or the whole branch.

## Step 2 - Read the full context

For every file in the diff, read the **full file**, not just the hunks. Most real findings are invisible in a hunk: the caller that breaks, the type that no longer fits, the sibling function with the same bug.

Then read what the repo expects of you before judging it:

- Instruction files: `fd -H -i '^(claude|agents)(\.local)?\.md$' <repo-root>` - root, `.claude/`, and per-directory. A convention stated there outranks your own taste.
- Config that encodes style: `.editorconfig`, `.eslintrc`, `.prettierrc`, `Directory.Build.props`, linter settings.

## Step 3 - Run the lenses

Pick the lenses, then spawn one subagent per lens in a single message so they run concurrently. Default three:

| Question | Lens |
|---|---|
| Does it work? | `/review-correctness` |
| Should it exist, in this shape? | `/review-simplicity` |
| Would we notice if it broke? | `/review-tests` |

Add `/agent-authoring` as a fourth **only** when the diff touches agent-facing text - a `SKILL.md`, `CLAUDE.md`, `AGENTS.md`, an MCP tool description, or a subagent prompt. Three lenses is the deliberate ceiling; every lens is a full context and the cost is real. For a diff that is **only** prose or instruction text, `/agent-authoring` **replaces** the code lenses rather than joining them.

Every spawn prompt contains, verbatim in substance:

- **The scope only.** The diff command or file list. Nothing about what the change is for or what you suspect - leaking your framing turns independent reviewers into copies of you.
- **The lens.** "Invoke `/review-correctness` and apply it to this scope."
- **No nesting.** "Do not spawn subagents. Do all the work yourself."
- **Shell rules.** "Use `rg` not grep, `fd` not find, `bat` not cat. Never use `rm`." Subagents default to POSIX tools unless told otherwise.
- **Evidence.** "Every finding names a concrete failing case - inputs or state, and the wrong result. If you cannot construct one, mark it unverified."
- **The report format.** Step 4 below.
- **The verdict.** "End with `VERDICT: PASS` or `VERDICT: FAIL` against your own lens's criteria. `FAIL` only when a Critical or Warning survives - Suggestions are reported in full and never fail a review. Do not soften a Critical or Warning, or inflate a nit into one."

Security, performance and readability have no lens of their own - cover them yourself in a direct pass over the diff, since they are cross-cutting and cheap: injection, hardcoded secrets, missing authn/authz, unvalidated input at a trust boundary, path traversal; N+1 queries, unbounded fetch, allocation in a hot path, accidental O(n²); naming that needs a comment to survive, a function doing several jobs, dead or commented-out code.

⚠️ Never simplify away input validation at a trust boundary, error handling that prevents data loss, security controls, or accessibility basics. A finding that removes one of those is wrong.

When the review turns on how the change behaves and it is observable in a running system, reading is not enough - drive it with `/manual-qa` and fold what you find into the findings below.

## Step 4 - Present findings

Merge findings that duplicate across lenses, then present one report. Open with two or three sentences: is this change in good shape, and is anything a blocker? The review is clean only when every lens returned `PASS`. Then findings, grouped by severity:

- **Critical** - must fix before merge. Bugs with a failing case, security holes, data-loss risk, a broken build or a failing test.
- **Warning** - should fix. Error-handling gaps, performance traps, future bugs, the change not doing what was specified, and any violation of a convention the repo actually states (an instruction file, a linter config, `.editorconfig`, the documented comment or naming rules).
- **Suggestion** - the implementer's call, and they may decline without justifying it. Readability, naming taste, minor refactors, a shorter form of something already correct, consistency the repo has no stated rule for.

**The severity is the verdict.** Every lens fails only on a surviving Critical or Warning. Suggestions are reported in full and never fail a review - a nit is a nit however many of them there are. When a finding could sit in either bucket, the deciding question is whether something outside your own taste says it is wrong: a failing case, a spec, or a rule written down in the repo. If nothing does, it is a Suggestion.

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
