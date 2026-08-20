---
name: review-tests
description: |-
  Trigger when the concern is the tests rather than the code - whether a change is covered, whether edge cases have cases, whether existing tests still guard what they claim, or flakiness. Also after deleting code, and when the same pass wrote both code and tests. One of /qa-loop's lenses.
  Keywords: test review, are there enough tests, test coverage, missing tests, untested, flaky, will tests catch this, brittle tests, regression test
---

# Review - Tests

Hunts gaps and lies in the test suite around a change. Scope, context and reporting come from `/code-review` Steps 1, 2 and 4 - read those first, then apply this lens instead of its Step 3.

Judge the tests against the change. A suite with high coverage and no test for the branch just added is a failing suite.

## Coverage of this change

- Every new branch, guard, and error path: is there a test that fails if it is removed?
- Behaviour that **changed**: did the existing tests change with it, or do they still assert the old contract, or worse, still pass because they never touched it?
- Code that was **deleted**: is anything left that would catch its removal breaking a caller?
- The bug being fixed: is there a test that fails on the old code and passes on the new? A fix without one invites the regression back.

## Edge cases that should have a case

Work the list against the change's actual inputs rather than reciting it: empty, null, zero, negative, one element, maximum size, duplicate entries, absent vs present-but-empty, unicode and case variation, concurrent invocation, timeout and partial failure.

## Test quality

**Asserting the wrong thing**
- Testing implementation detail (call counts, private state) instead of observable behaviour, so the test breaks on refactor and passes on regression
- Assertions so loose they cannot fail (`assertNotNull` on a value that is always constructed)
- A test whose name promises more than its body checks

**Tests that can't fail**
- Mocked so heavily the production path never runs
- Setup that silently swallows the exception the test exists to catch
- A conditional or `try/catch` in the test body that turns a failure into a pass

**Flakiness**
- Real sleeps, wall-clock or timezone dependence, `DateTime.Now`
- Reliance on iteration or file-system ordering, or on a shared mutable fixture
- Shared state between tests, or dependence on test execution order
- A live network, port, or container the test does not own

**Placement**
- Does it sit at the level the repo uses for this kind of logic - unit, integration, end-to-end? A slow test doing a fast test's job is a finding.
- Does it follow the repo's existing test conventions and helpers rather than inventing new ones?

## Verifying flakiness

Do not assert flakiness from reading. Run the suspect test repeatedly and report the actual rate:

```bash
for i in $(seq 1 20); do <the repo's single-test command> || echo "FAILED run $i"; done
```

## Reporting

Use `/code-review` Step 4. Each finding names the untested path or the false-confidence test, and the specific case that should exist. Say plainly when the tests are adequate - "more tests" is not automatically the right answer, and a test that cannot fail is worse than no test.

## Verdict

End with one line: `VERDICT: PASS` or `VERDICT: FAIL`. This judgement is yours, not the caller's.

`FAIL` if any of these hold:

- A new or changed logic path has no test that fails when that logic is broken
- A bug fix has no test that fails on the old code and passes on the new
- A test in scope asserts something that cannot fail, or passes without exercising the production path
- Behaviour changed and its existing tests did not
- Flakiness was suspected and not measured by repeat runs

`PASS` if none hold. Coverage percentages are not evidence; a named failing case for each new branch is.
