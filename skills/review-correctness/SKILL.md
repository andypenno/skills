---
name: review-correctness
description: |-
  Trigger when the question is whether a change is right rather than tidy - a suspected bug, "what could break", "did we miss anything", edge cases, or the blast radius of a fix. Also after a fix to shared code, to check every affected call site and whether the same bug exists elsewhere.
  Keywords: correctness review, what could break, did we miss anything, edge cases, blast radius, other call sites, same bug elsewhere, regression risk
---

# Review - Correctness

Hunts wrong behaviour and unhandled states. Work from the diff or files in scope, asking if it is unclear what to review. Read each in full - not just the hunks, since the caller that breaks and the sibling with the same bug live outside them - plus the repo's instruction files (`fd -HI -E node_modules -E worktrees -i '^(claude|agents)(\.local)?\.md$'`) and style config.

## What to check

**Logic**
- Off-by-one, inverted conditions, wrong operator, wrong default when a value is absent
- Branches that can't be reached, and branches that silently fall through
- Comparison semantics: reference vs value, case sensitivity, culture-dependent string compare, float equality

**State the code doesn't expect**
- Null, empty, zero, negative, single-element, maximum-size
- Absent vs present-but-empty (they are different, and the difference is usually a bug)
- Partial failure midway through a multi-step operation - what is left behind?

**Failure paths**
- Errors swallowed, logged-and-continued, or rethrown with the cause lost
- Cleanup that only runs on the success path (missing `finally`/`defer`/`using`)
- Retries without a ceiling, or without idempotency at the other end

**Contracts**
- Does the caller's assumption still hold after this change? Check every caller, not the one in the diff.
- API/library used per its actual documented behaviour, not its plausible behaviour
- Nullability, ownership and lifetime annotations that the change now violates

**Concurrency**
- Shared mutable state reached from more than one path
- Check-then-act races, unsynchronised lazy init, async work whose result outlives its scope

## Blast radius - the part reviews usually skip

A fix proven at one call site is not a fix. Before reporting, enumerate what else is affected:

```bash
rg -n '<the changed symbol>'                 # every caller and reference
rg -n '<the buggy pattern>'                  # the same mistake elsewhere
rg -uu -n '<the changed key or literal>'     # config, fixtures, generated files, ignored files
```

⚠️ `rg` and `fd` skip hidden and gitignored files by default. A rename that misses a gitignored config file is the classic silent failure - use `-uu` / `--hidden --no-ignore` when the population must be exhaustive.

Report explicitly on: sibling callers left unfixed, the same bug pattern surviving elsewhere, and config or data files that reference what changed.

## Reporting

Each finding: `path:line`, what is wrong and why, a **concrete failing case** (the input or state, and the wrong output or crash), and a fix. Group by severity - Critical and Warning must fix, a Suggestion is the implementer's call and never fails the review. If you cannot construct the failing case, say the finding is unverified rather than presenting a guess as a defect.

## Verdict

End with one line: `VERDICT: PASS` or `VERDICT: FAIL`. This judgement is yours, not the caller's.

`FAIL` only on a Critical or Warning. These are the ones that qualify:

- A confirmed defect - a reproducible failing case, a broken build, or a failing test (Critical)
- A caller or config file this change actually breaks, left unfixed (Critical). Report it even when fixing it falls outside the scope you were given, and say so
- An error or failure path the change added or touched with undefined behaviour (Warning)
- The change does not do what the spec, ticket or instruction file says it should (Warning)
- A blast-radius sweep that was **relevant to this diff** and you could not run here (Warning, naming the sweep)

`PASS` otherwise, and a `PASS` may carry Suggestions. Specifically not a failure: a finding you could not construct a failing case for (report it as unverified), the same pattern surviving in code this change never touched, and a sweep that does not apply to the diff at hand - a prose or config-only change has no callers to sweep.
