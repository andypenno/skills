---
name: triage
description: |-
  Trigger when something that was working has broken and the question is when and why - a service down, DNS or proxy failing, a container not coming back, a red pipeline, "why does this keep breaking". Also on "it broke overnight" and on any repeat of a fault that was previously fixed.
  Keywords: broke, went down, stopped working, not responding, why is X down, when did it break, why does this keep breaking, again since last night, pipeline failed, CI failed, deep dive, what happened
---

# Triage

Diagnose a live failure. The answer is a timeline and a cause, not a guess and a restart.

⚠️ **Diagnosis is not authorization.** Restarting a service, pruning, killing jobs and re-running pipelines are all stateful actions. If the user asked why it broke, answer that. If they also asked you to bring it back, do both and say which is which.

## Step 1 - Establish the window before hypothesising

The most common failure of a triage is a plausible cause that does not match the timing. Get the window first, and let it eliminate suspects for you.

- When did it last work, and when did it first fail? Prefer evidence over the user's estimate.
- Logs, unit journals, container restart counts and timestamps, monitoring history, last modification times on config.
- Bound it as tightly as the evidence allows, and state the bound.

A cause that cannot explain the window is not the cause, however plausible it looks.

## Step 2 - Correlate against what runs on a schedule

"Overnight" and "since last night" almost always mean something scheduled did it. Before reading application code, list what ran inside the window:

- Backup jobs, snapshot and volume operations, image pulls and auto-updates
- Cron, systemd timers, launchd agents, scheduled automations
- Certificate renewal and DNS refresh
- Host-level events: reboots, OOM kills, disk pressure, filesystem remounts

If the fault reproduces on a schedule, the schedule is the lead.

## Step 3 - Check whether this already happened

`why does this keep breaking` is a different question from `why is it broken`, and it is the more important one.

Search prior fixes for the same symptom - commit history, notes, monitoring history, previous incidents. If this is a recurrence, the earlier fix treated a symptom, and the deliverable is the cause that survived it.

## Step 4 - Prove the cause

Do not stop at correlation. Establish the mechanism: the specific dependency, resource, permission, or ordering that failed, evidenced from the real logs and config at report time.

Where safe and non-destructive, reproduce it. A cause you can trigger is a cause; a cause you inferred is a hypothesis, and must be labelled one.

## Step 5 - Report

- **Timeline** - last known good, first failure, the correlated event
- **Cause** - the mechanism, with the evidence
- **Restore** - what brings it back, and whether that has been done or is being proposed
- **Recurrence** - will this happen again on the next schedule tick? If your fix does not answer that, say so rather than implying it is closed
- **Blast radius** - what else depends on the failed component and is quietly degraded

## CI mode

A red pipeline is the same procedure with different sources: which stage failed, whether it fails on a rerun (flake versus real), whether it fails on the base branch too (yours or pre-existing), and what changed in the window. Read the actual job log rather than the summary - and get the failing job's log specifically, not the whole pipeline's output.
