---
name: qa-loop
description: |-
  Trigger when iterating on a change with a review after each round - "it's time for a qa loop", "run the loop", rounds until it comes back clean. Each round runs a /review-full pass, then you fix and re-run. Expensive: for a single review with no loop, use /review-full.
  Keywords: qa loop, qa round, run the loop, another round, iterate until clean, review after each change, fresh eyes, keep looping
---

# QA Loop

Review between every iteration: each round is a `/review-full` pass, you fix what it finds, and you re-run until a round comes back clean. This skill owns the loop - the pass, the lenses and the report all come from `/review-full`.

## Step 1 - Fix the scope once

Resolve the diff under review before the first round, using `/review-full` Step 1. Every round in this session reviews the **same** scope, so a later round can be compared against an earlier one - do not let it drift as you fix.

## Step 2 - Run a round

Run a `/review-full` pass over the fixed scope. It picks the lenses, spawns them as independent subagents on scope alone, and returns each lens's `PASS`/`FAIL` with findings. That includes `/manual-qa` as `/review-full` Step 2 specifies, in every round and not only the first. The independence is the point, and `/review-full` Step 2 enforces it - do not add framing of your own on top.

## Step 3 - Triage before fixing

⚠️ **You do not own the verdict.** Each lens defines its own pass/fail criteria and returns `PASS` or `FAIL`. You may reject an individual *finding* with a recorded reason, but you cannot turn a lens's `FAIL` into a pass, and you cannot declare the work done because what remains looks minor to you. Deciding for yourself what counts as finished is the exact failure this loop exists to prevent.

Findings are claims, not work. `/review-full` already merged duplicates across lenses; judge each one:

- **Confirmed** - the failing case is real and reproducible. Fix it.
- **Unverified** - plausible, no failing case. Spend one cheap check to settle it; if it survives, fix it, if not, drop it.
- **Rejected** - wrong, or already handled elsewhere in the code the reviewer didn't read. Record why in one line.

Reviewers looking for problems will find some that aren't there. Accepting every finding uncritically is its own failure, and it grows the diff the simplicity lens just asked you to shrink.

Suggestions are the implementer's call. Take the ones you agree with, list the rest in the closing report, and move on - they do not need a justification and they do not hold a round open.

One escape hatch, for the case where a lens is right and the fix is not yours to make: a Critical or Warning whose fix falls outside the scope you were given goes to the **user** with the reviewer's reasoning and your recommendation. Record it as escalated. You still may not re-grade it or absorb it silently, and the round stays open until the user rules on it.

Fix confirmed findings, smallest correct change each, at the root rather than at the symptom. Never expand the scope of the change beyond what the user or ticket specified because the reviewer found a problem. You may notify the user that the fix is larger than they expected, but do not change the scope to satisfy a reviewer.

## Step 4 - Prove the fixes

Re-run the check that would fail if the fix were wrong: the build, the affected tests, or the original failing case on the real target. A round is not closed by "applied the fixes" - it is closed by the evidence.

Where the change is only observable in a running system, drive it there with `/manual-qa`. Say plainly if verification was impossible in this environment rather than implying it passed.

## Step 5 - Next round, or stop

Run a fresh `/review-full` round on the same scope. Each round is independent by construction, so do not pass in what the last round found or what you fixed.

Stop when **every lens returns `PASS` in the same round** - not after a fixed number of rounds. A round in which any lens returns `FAIL` is an open round, even if you disagree with it, and so is one where `/review-full`'s own pass (its Step 3) found a Critical or Warning. A `PASS` carrying Suggestions is still a `PASS`: there is no round that ends with nothing left anyone could say, and chasing one is how this loop turns into a treadmill.

Two exits that are not a pass, and must be said out loud rather than absorbed:

- A lens returns `FAIL` on a finding you reject. Fix it, or take it to the user with your reasoning. Do not re-run hoping for a kinder reviewer.
- A lens could not complete a check in this environment. That is `FAIL`, and the closing report names the check and why.

Track across rounds so the picture is honest:

| Round | Lens | Verdict | Confirmed | Rejected | Fixed |
|---|---|---|---|---|---|

## Closing report

Lead with what is **not** done: unverified findings, rejected findings the user may disagree with, anything you could not check in this environment. Then the table, then the fixes made. Do not grade the result.
