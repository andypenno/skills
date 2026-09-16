---
name: manual-qa
description: |-
  Trigger to confirm a change works by running it rather than reading it - exercise the feature by hand, reproduce the original failing case, smoke-test a UI or CLI, verify behaviour in the running system.
  Keywords: manual qa, test it by hand, run it, drive the feature, smoke test, does it actually work, verify in the running app, reproduce the bug, exercise the change
---

# Manual QA

Behavioural verification by running the change, not reading it. A diff that reads correct still ships the bug; this drives the real system and reports what it observed.

## Step 1 - Decide what "works" means

Name the observable outcome before touching anything. A bug fix: the original failing case and its expected result. A feature: the behaviour the ticket asked for. A refactor: the behaviour that must stay identical. If the change has no runtime behaviour - prose, a constant, a type-only edit - say so and stop, there is nothing to drive.

## Step 2 - Get it running

Bring up the smallest real surface that exercises the change: the CLI command, the dev server and the one screen, the single test binary, the script with real inputs. Prefer the path a user actually takes over a synthetic harness. If it cannot run in this environment, stop and say so plainly - never infer the result from the code.

## Step 3 - Exercise it

- **The original case first.** Reproduce the exact input or steps from the bug report or ticket, and check the outcome from Step 1.
- **The happy path**, end to end.
- **The edges you would worry about.** Empty, missing, malformed, large, repeated, cancelled midway - the states the change newly touches. A few pointed cases beat a long checklist.
- **What it might have broken.** The adjacent behaviour that shared the code you changed.

Record the command, the input, and the actual output - not a summary of intent.

## Step 4 - Report

Lead with what you could **not** verify: cases you could not set up, anything the environment blocked. Then, per case: what you drove, the actual result, and pass or fail against Step 1.

- A reproduced-then-fixed original case is the strongest evidence a fix works. Show it.
- Never present reasoning as a result. "Should return 404" is not "returned 404" - if you did not run it, say edited, not verified.
- A case that failed is a finding: the input, the wrong result, and the expected result.
