---
name: review-simplicity
description: |-
  Trigger when the question is whether code should exist at all - what can be deleted, over-engineering, over-abstraction, bloat, boilerplate, or a change bigger than its problem. Also when reviewing LLM-written code, where speculative abstraction is the default failure, and when auditing a whole repo for bloat rather than a diff.
  Keywords: over-engineered, over-abstracted, what can we delete, simplify, too complex, bloat, boilerplate, YAGNI, unnecessary abstraction, duplication, dead code, audit for bloat, what can I delete from this repo
---

# Review - Simplicity

Hunts code that shouldn't exist. Work from the diff or files in scope, asking if it is unclear what to review. Read each in full plus the repo's instruction files (`fd -HI -E node_modules -E worktrees -i '^(claude|agents)(\.local)?\.md$'`) and style config.

Judge only against conventions the reviewed repo states in those files. Rules from your own operating context, like a personal global config, are not the repo's - suggest one if you like, but it is not a finding against someone else's code.

This lens deletes; it does not hunt bugs.

It also works with no diff at all: pointed at a whole tree rather than a change, it becomes an over-engineering audit, ranked biggest cut first.

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

One line per finding, each tagged with the rung it failed:

- `delete:` built for a requirement nobody stated, or dead already. Replacement: nothing.
- `reuse:` the repo already has this. Name the existing helper, type or pattern.
- `stdlib:` hand-rolled what the standard library ships. Name the function.
- `native:` a dependency or hand-written code doing what the platform does. Name the feature.
- `shrink:` same behaviour, fewer lines. Show the shorter form.

End with the number that matters: `net: -<N> lines, -<M> deps possible.` A finding with no replacement to name is not yet a finding.

Prefer a shorter diff over a cleverer one. If the honest answer is "this is about the right size", say that and stop.

## Verdict

End with one line: `VERDICT: PASS` or `VERDICT: FAIL`. This judgement is yours, not the caller's.

`FAIL` only on a Critical or Warning. In this lens that means:

- Dead code, commented-out code, or an unreferenced export was introduced (Warning)
- The same logic was added twice where a shared callee is the obvious home (Warning)
- A whole layer, dependency, or configuration surface was added for a requirement nobody stated (Warning)
- A comment or naming rule the repo states, in an instruction file or a linter config, was broken (Warning)

`PASS` otherwise, and a `PASS` may carry Suggestions. The ladder findings below Warning grade are Suggestions, and the implementer may decline them: a helper with one caller today, something the stdlib does slightly better, a block that could be three lines shorter, a `try/catch` that is merely redundant. Report every one of them, then pass.

Nothing in **Where laziness stops** is ever a finding at any severity - proposing to remove one of those is itself the mistake.
