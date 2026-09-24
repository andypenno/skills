---
name: review
description: |-
  Trigger to review a diff - "let's do a code review on this", review this PR or MR, a second opinion before merge. Prefer this over the built-in /code-review command (alias /review), which does not fan out to the lens subagents and does not route findings through /mr-comments. Prefer /review-correctness, /review-simplicity or /review-tests when the user names one concern.
  Keywords: code review, full review, review pass, review this PR, review this MR, review this diff, check this code, second opinion, review my changes
---

# Full review

The entry point for a review: one pass over a diff by independent lens subagents, merged into a single report.

## Step 1 - Determine the scope

Ask the user what they want reviewed if it's not clear. The scope is a command the lenses will run, plus the file list it yields. Run only the file-list form now; the diff text is for the lenses and Step 3.

| Scope | The lenses run | You run now |
|-------|-------------------|---|
| Unstaged working changes | `git diff` | `git diff --name-only` |
| Staged changes | `git diff --cached` | `git diff --cached --name-only` |
| All uncommitted changes | `git diff HEAD`, plus the untracked files in full | `git diff HEAD --name-only` and `git ls-files --others --exclude-standard` |
| The whole branch | `git diff $(git merge-base HEAD main)...HEAD` | the same with `--name-only` |
| Between branches/commits | `git diff <ref1>..<ref2>` | the same with `--name-only` |
| A specific commit | `git show <commit>` | `git show --name-only --format= <commit>` |
| A GitHub PR | `gh pr diff N` | `gh pr diff N --name-only` |
| A GitLab MR | `glab mr diff N --raw` | `glab api "projects/:fullpath/merge_requests/N/diffs?per_page=100" --paginate --output ndjson \| jq -r .new_path` |
| Specific files | the file list | nothing |
| The whole tree, no diff | the tree root. An audit, not a review - only `/review-simplicity` and `/review-tests` make sense at this scope | nothing |

If the user says "review my changes" without more context, default to `git diff --cached`. If nothing is staged, ask whether they mean all uncommitted changes or the whole branch.

## Step 2 - Spawn the lenses, before you read the diff

You are the orchestrator. You do not write lens findings, you merge them. Your next action after Step 1 is the spawn, one message containing one subagent call per lens so they run concurrently. Reading the change first is how this goes wrong. Once you hold the whole diff, writing the findings yourself looks quicker than spawning, and the lenses get skipped. Default three:

| Question | Lens |
|---|---|
| Does it work? | `/review-correctness` |
| Should it exist, in this shape? | `/review-simplicity` |
| Would we notice if it broke? | `/review-tests` |

Add `/agent-authoring` as a fourth **only** when the diff touches agent-facing text - a `SKILL.md`, `CLAUDE.md`, `AGENTS.md`, an MCP tool description, or a subagent prompt. Three reading lenses is the deliberate ceiling (`/manual-qa` below sits outside it); every lens is a full context and the cost is real. For a diff that is **only** prose or instruction text, `/agent-authoring` **replaces** the code lenses rather than joining them.

When the change has runtime behaviour a running system can show, the same message also spawns a `/manual-qa` subagent. It gets the scope, the ticket or original failing case, the same no-nesting and shell lines as the lenses, and a `git worktree` of the change if running it writes to the tree. It ends with `VERDICT: PASS` or `VERDICT: FAIL` against the outcome its own Step 1 names; a case it could not run is `FAIL`. That verdict counts as a lens's. Driving it yourself does not count: by then you know what you expect to see.

`/agent-authoring` "Writing a spawn prompt" holds the reasons; this is the text each lens prompt carries, verbatim in substance:

- **The scope only.** The diff command or file list, run against the absolute repo path (`git -C <abs-path> ...`), and nothing about what the change is for or what you suspect.
- **The lens.** "Invoke `/review-correctness` and apply it to this scope."
- **No nesting, read-only.** "Do not spawn subagents or edit the working tree. Do all the work yourself."
- **Shell rules.** "Use `rg` not grep, `fd` not find, `bat` not cat. Never use `rm`."
- **Evidence and format.** "Report in your lens's own Reporting format, or as `path:line`, what is wrong, evidence, fix if it has none. Every finding carries the evidence your lens demands - a concrete failing case, or the named replacement. If you cannot supply it, mark the finding unverified."
- **The verdict.** "End with `VERDICT: PASS` or `VERDICT: FAIL` against your own lens's criteria. `FAIL` only when a Critical or Warning survives - Suggestions are reported in full and never fail a review. Do not soften a Critical or Warning, or inflate a nit into one."

## Step 3 - Your own pass, while the lenses run

For every file in the diff, read the **full file**, not just the hunks. Most real findings are invisible in a hunk: the caller that breaks, the type that no longer fits, the sibling function with the same bug.

Then read what the repo expects of you before judging it:

- Instruction files: `fd -HI -E node_modules -E worktrees -i '^(claude|agents)(\.local)?\.md$' <repo-root>` - root, `.claude/`, and per-directory. A convention stated there outranks your own taste.
- Config that encodes style: `.editorconfig`, `.eslintrc`, `.prettierrc`, `Directory.Build.props`, linter settings.

Security, performance and readability have no lens of their own - cover them yourself in a direct pass over the diff, since they are cross-cutting and cheap: injection, hardcoded secrets, missing authn/authz, unvalidated input at a trust boundary, path traversal; N+1 queries, unbounded fetch, allocation in a hot path, accidental O(n²); naming that needs a comment to survive, a function doing several jobs, dead or commented-out code.

⚠️ Never simplify away input validation at a trust boundary, error handling that prevents data loss, security controls, or accessibility basics. A finding that removes one of those is wrong.

## Step 4 - Present findings

Merge findings that duplicate across lenses, then present one report. Open with two or three sentences: is this change in good shape, and what blocks merge? Only a Critical blocks merge, so name the Criticals or say none do. Never call a Warning "fix before merge" or present a lens `FAIL` as a block; if you would hold the merge on a finding, grade it Critical. The review is clean only when every lens returned `PASS`, and a lens that never ran cannot pass. If you did not fan out, say so, and the result is not a review. Then findings, grouped by severity:

- **Critical** - must fix before merge. Bugs with a failing case, security holes, data-loss risk, a broken build or a failing test.
- **Warning** - should fix. Error-handling gaps, performance traps, future bugs, the change not doing what was specified, and any violation of a convention the repo actually states (an instruction file, a linter config, `.editorconfig`, the documented comment or naming rules).
- **Suggestion** - the implementer's call, and they may decline without justifying it. Readability, naming taste, minor refactors, a shorter form of something already correct, consistency the repo has no stated rule for.

**The severity is the verdict.** Every lens fails only on a surviving Critical or Warning. Suggestions are reported in full and never fail a review - a nit is a nit however many of them there are. When a finding could sit in either bucket, the deciding question is whether something outside your own taste says it is wrong: a failing case, a spec, or a rule written down in the repo. If nothing does, it is a Suggestion.

Each finding in the merged report carries:

1. `path/to/file.ts:42`
2. What is wrong, and why it matters
3. Its evidence - a concrete failure scenario (inputs or state that produce the wrong result), or for a simplicity finding the named replacement. A finding with neither is a guess; label it as one or drop it.
4. A concrete fix

Posting the report to a PR or MR is outward-facing: never post on your own initiative, and never without the user's approval. Once approved, loading `/mr-comments` is a hard requirement before anything goes out - not a suggestion, and it holds even mid-task straight after this review. Do not run `gh pr comment`, `gh api .../comments`, `glab mr note`, or any other post command directly from here. `/mr-comments` alone defines the commands, how comments are grouped, anchored, batched, worded and signed, and the propose-before-send flow, and posting without it is a failure even after approval. Only the substantive findings go out, what you would have graded Critical or Warning, plus any Suggestion the user asks for.

## Guidelines

- Specific and actionable. "This could be better" is noise; "this `forEach` mutates the input - use `map`" is a review.
- Separate genuine issues from taste. Don't bikeshed style the repo has no convention for.
- Weigh the context. A prototype and a payment path have different bars.
- Say so when the change is fine. Manufacturing findings to look thorough wastes the reader's time and trains them to ignore you.
- Three real findings beat thirty nitpicks. Rank, then cut.
