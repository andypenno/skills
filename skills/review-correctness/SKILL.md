---
name: review-correctness
description: |-
  Trigger when the question is whether a change is right rather than tidy - a suspected bug, "what could break", "did we miss anything", edge cases, or the blast radius of a fix. Also after a fix to shared code, to check every affected call site and whether the same bug exists elsewhere. One of /qa-loop's lenses.
  Keywords: correctness review, what could break, did we miss anything, edge cases, blast radius, other call sites, same bug elsewhere, regression risk
---

# Review - Correctness

Hunts wrong behaviour and unhandled states. Scope, context and reporting come from `/code-review` Steps 1, 2 and 4 - read those first, then apply this lens instead of its Step 3.

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

Use `/code-review` Step 4. One extra requirement: every finding names a **concrete failing case** - the input or state, and the wrong output or crash. If you cannot construct one, say the finding is unverified rather than presenting a guess as a defect.

## Verdict

End with one line: `VERDICT: PASS` or `VERDICT: FAIL`. This judgement is yours, not the caller's.

`FAIL` if any of these hold:

- A confirmed defect exists - any finding with a reproducible failing case
- A caller, config file, or sibling occurrence of the same pattern is affected and left unfixed
- An error or failure path the change added or touched has undefined behaviour
- You could not complete the blast-radius sweeps in this environment

`PASS` requires all four absent. An incomplete check is `FAIL` with the check named - never a `PASS` with a caveat.
