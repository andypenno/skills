---
name: qa-loop
disable-model-invocation: true
description: |-
  Trigger when the user wants a change checked by independent reviewers rather than by you - a QA loop, review round, multiple subagents, an unbiased or fresh-perspective review, or rounds until nothing new comes back. Expensive: prefer /code-review for a single pass.
  Keywords: qa loop, qa round, run the loop, another round, spin up subagents, independent review, unbiased, fresh eyes, don't bias them
---

# QA Loop

Round-based adversarial review by independent subagents. You do not review the work yourself - you were the one who wrote it, so your review inherits every assumption that produced the bugs.

## Step 1 - Fix the scope once

Resolve the diff under review before spawning anything, using `/code-review` Step 1. Every round in this session reviews the same scope, so a later round can be compared against an earlier one.

Then pick the lenses. Default three:

| Lens | Skill |
|---|---|
| Does it work? | `/review-correctness` |
| Should it exist, in this shape? | `/review-simplicity` |
| Would we notice if it broke? | `/review-tests` |

Add `/agent-authoring` as a fourth lens **only** when the diff touches agent-facing text - a `SKILL.md`, `CLAUDE.md`, `AGENTS.md`, an MCP tool description, or a subagent prompt. Three lenses is the deliberate default ceiling; every lens is a full-context subagent and the cost is real.

## Step 2 - Spawn the round

One subagent per lens, all in a single message so they run concurrently.

Every prompt must contain, verbatim in substance:

- **The scope only.** The diff command or file list. Nothing about what you built, why, what you were worried about, or what a previous round found.
- **The lens.** "Invoke `/review-correctness` and apply it to this scope."
- **No nesting.** "Do not spawn subagents. Do all the work yourself."
- **Shell rules.** "Use `rg` not grep, `fd` not find, `bat` not cat. Never use `rm`." Subagents default to POSIX tools unless told otherwise.
- **Evidence.** "Every finding names a concrete failing case - inputs or state, and the wrong result. If you cannot construct one, mark the finding unverified."
- **The report format.** `/code-review` Step 4.
- **The verdict.** "End your report with `VERDICT: PASS` or `VERDICT: FAIL`, judged against the pass/fail criteria in your own lens skill. You own that call. Do not soften it, and never report PASS for a check you could not complete."

⚠️ The single thing that ruins this: leaking your own framing. "I refactored the dedupe logic, check I didn't break it" tells the reviewer where to look and where not to. It converts three independent reviewers into three copies of you.

## Step 3 - Triage before fixing

⚠️ **You do not own the verdict.** Each lens defines its own pass/fail criteria and returns `PASS` or `FAIL`. You may reject an individual *finding* with a recorded reason, but you cannot turn a lens's `FAIL` into a pass, and you cannot declare the work done because what remains looks minor to you. Deciding for yourself what counts as finished is the exact failure this loop exists to prevent.

Findings are claims, not work. Merge duplicates across lenses, then judge each one:

- **Confirmed** - the failing case is real and reproducible. Fix it.
- **Unverified** - plausible, no failing case. Spend one cheap check to settle it; if it survives, fix it, if not, drop it.
- **Rejected** - wrong, or already handled elsewhere in the code the reviewer didn't read. Record why in one line.

Reviewers looking for problems will find some that aren't there. Accepting every finding is as bad as reviewing your own work, and it grows the diff the simplicity lens just asked you to shrink.

Fix confirmed findings, smallest correct change each, at the root rather than at the symptom. Never expand the scope of the change beyond what the user or ticket specified because the reviewer found a problem. You may notify the user that the fix is larger than they expected, but do not change the scope to satisfy a reviewer.

## Step 4 - Prove the fixes

Re-run the check that would fail if the fix were wrong: the build, the affected tests, or the original failing case on the real target. A round is not closed by "applied the fixes" - it is closed by the evidence.

Where the change is only observable in a running system, drive it there. Say plainly if verification was impossible in this environment rather than implying it passed.

## Step 5 - Next round, or stop

Spawn a fresh round on the same scope. **Fresh subagents, same unbiased prompts** - do not tell them what the last round found or what you fixed, or they will confirm your work instead of testing it.

Stop when **every lens returns `PASS` in the same round** - not after a fixed number of rounds, and not when the findings start looking minor. A round in which any lens returns `FAIL` is an open round, even if you disagree with it.

Two exits that are not a pass, and must be said out loud rather than absorbed:

- A lens returns `FAIL` on a finding you reject. Fix it, or take it to the user with your reasoning. Do not re-run hoping for a kinder reviewer.
- A lens could not complete a check in this environment. That is `FAIL`, and the closing report names the check and why.

Track across rounds so the picture is honest:

| Round | Lens | Verdict | Confirmed | Rejected | Fixed |
|---|---|---|---|---|---|

## Closing report

Lead with what is **not** done: unverified findings, rejected findings the user may disagree with, anything you could not check in this environment. Then the table, then the fixes made. Do not grade the result.
