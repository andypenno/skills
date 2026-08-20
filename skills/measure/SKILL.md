---
name: measure
description: |-
  Trigger before running any benchmark, profile, leak hunt, load test or A/B comparison, and when the user asks whether a change actually improved anything or wants a comparison against a baseline. Also when a run already underway is slower than expected, has no estimate, or has no way to be stopped.
  Keywords: benchmark, profile, profiling, measure, is this a leak, memory leak, performance comparison, compare against master, baseline, before and after, how long will this take, load test, is it faster
---

# Measure

Design the experiment before running it. Every expensive measurement failure is a design failure discovered hours in.

## Step 1 - State the experiment before touching anything

Write these down and show them to the user *before* the first run:

- **Hypothesis** - the specific claim this will confirm or kill
- **The one axis you vary** - everything else held constant
- **The scenario matrix** - the exact set of runs, named. Group by the dimension you care about, not one run per input. Reporting per-input when you wanted per-category is the classic waste.
- **The baseline** - the commit or config you are comparing against, run **in the same batch** under the same conditions. A baseline measured last week is not a baseline.
- **The kill criterion** - what result would make you stop early

## Step 2 - The pre-flight contract

⚠️ Never launch a long run without these. Announce them, then start.

| Item | Why |
|---|---|
| Estimated wall clock | An estimate the user disagrees with is how a wrong experiment gets caught in minutes instead of hours |
| Parallelism used, and why | See below |
| Progress and result file on disk | An OOM-killed container must not take the results with it |
| The exact command to stop it | The user should never have to hunt for how to kill your run |

Run the **smallest variant that could invalidate the hypothesis first**. If a five-minute run settles it, the ninety-minute matrix was never needed.

**Parallelism rule:** parallelise when the contended resource is not the one under test. Memory-bound runs can go wide on CPU; CPU benchmarks cannot. Serialising a memory measurement across eight cores because "benchmarks should be serial" wastes hours for no fidelity.

## Step 3 - Run

- Sample often enough to see the shape, not just the endpoints. A leak hunt that samples twice measures nothing.
- Keep raw logs. Summaries that cannot be re-derived are not evidence.
- Before re-running, move prior results aside into a dated or `pre-fix/` folder. Overwriting the run you are comparing against is unrecoverable.
- Report progress at intervals, not on request.

## Step 4 - Report

- **Distribution, not just peak.** Minimum, steady state, peak, and what was reclaimed. Peak alone hides both the leak and the fix.
- **Against the baseline, always.** An absolute number answers no question anyone asked. State the delta and whether it clears the noise.
- **Noise first.** Two runs of the same config bound your resolution. A 3% delta on 10% variance is nothing, and saying so is the finding.
- **Answer the original question in the first line.** "Did our change fix the key issues" is the question; the table is support.
- Bulk numbers and comparisons go to a file or a rendered report, never streamed into chat. Pair with `/dataviz` for chart design and `/html` for a shareable document.

## Honesty

Say plainly when a measurement did not run, was killed, or produced results you do not trust. A number you cannot defend is worse than no number, because the next decision gets built on it.
