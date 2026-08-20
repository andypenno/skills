---
name: review-simplicity
description: |-
  Trigger when the question is whether code should exist at all - what can be deleted, over-engineering, over-abstraction, bloat, boilerplate, or a change bigger than its problem. Also when reviewing LLM-written code, where speculative abstraction is the default failure. One of /qa-loop's lenses.
  Keywords: over-engineered, over-abstracted, what can we delete, simplify, too complex, bloat, boilerplate, YAGNI, unnecessary abstraction, duplication, dead code
---

# Review - Simplicity

Hunts code that shouldn't exist. Scope, context and reporting come from `/code-review` Steps 1, 2 and 4 - read those first, then apply this lens instead of its Step 3.

This lens deletes; it does not hunt bugs. Pair it with `/review-correctness`.

## The ladder

For each addition in the diff, find the first rung that holds. Anything above the rung it actually needed is a finding.

1. **Does this need to exist?** Built for a requirement nobody stated. Delete it.
2. **Does it already exist here?** A helper, type, or pattern a few files over. Reuse it. Re-implementing what the codebase already has is the single most common finding.
3. **Does the standard library do it?** Use it.
4. **Does the platform do it?** A DB constraint over app-side checking, CSS over JS, a native input over a widget library.
5. **Does an already-installed dependency do it?** Use it. Never a new dependency for what a few lines cover.
6. **Can it be one line?** Make it one line.

## Specific smells

**Speculative structure**
- An interface, base class, or protocol with exactly one implementation
- A factory, registry, or strategy map with one entry
- Config, env vars, or feature flags for a value that never varies
- Parameters no caller ever passes non-default
- Generic type parameters used at exactly one type

**Reinvention**
- Hand-rolled date maths, string padding, deep clone, retry, debounce, LRU, argument parsing
- A hand-rolled version of something the repo already wraps

**Duplication and misplacement**
- The same fix applied in two places because the shared function was the right place. Fix it once, where all callers route through.
- Logic sitting at the wrong altitude: per-caller guards where one guard in the callee would do

**Defensive scaffolding**
- `try/catch` around code that cannot throw, or that rethrows unchanged
- Null checks on values the type system already guarantees
- Casts to `any`/`object`/`dynamic` that exist only to silence the type checker
- Validation repeated at every layer after the boundary already validated it

**Leftovers**
- Dead code, commented-out code, unreferenced exports, TODOs for work already done
- Comments restating the line below them, or narrating the change rather than the code

## Where laziness stops

These are never findings. Do not propose removing them:

- Input validation at a trust boundary
- Error handling that prevents data loss
- Security controls and authorisation checks
- Accessibility basics
- Anything the user explicitly asked for

## Reporting

Use `/code-review` Step 4, one line per finding: **location - what to cut - what replaces it**. Prefer a shorter diff over a cleverer one. If the honest answer is "this is about the right size", say that and stop.

## Verdict

End with one line: `VERDICT: PASS` or `VERDICT: FAIL`. This judgement is yours, not the caller's.

`FAIL` if any of these hold:

- Something added can be deleted, or replaced by what already exists in the repo, the standard library, or an installed dependency, with no behaviour change
- An abstraction has exactly one caller or one implementation and no stated second use
- The same logic appears twice where a shared callee is the right home
- Dead code, commented-out code, or an unreferenced export was introduced

`PASS` if none hold. Nothing in **Where laziness stops** is ever a `FAIL` - proposing to remove one of those is itself the mistake.
