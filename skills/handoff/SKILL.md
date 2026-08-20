---
name: handoff
disable-model-invocation: true
description: |-
  Trigger when work needs to continue in a different session or by a different agent - the user asks for a prompt for the next agent, a handoff, a summary of where things are up to, or is stopping mid-task. Also when the next step needs access this session lacks (a running server, another repo, another machine).
  Keywords: handoff, hand over, prompt for the next agent, next session, where were we, where is it up to, pick this up later, self-contained prompt, pass this on, brief the next agent
---

# Handoff

Emit **one fenced block** that a fresh agent can be started with, containing everything it needs and nothing it can look up. The reader has no memory of this session and no access to your reasoning.

This is a forward brief, not a session summary. The test is not "did I describe what happened" but "can the next agent take the next action without asking me a question".

## Gather first

Do not write from memory. Read the actual state:

```bash
git -C <repo> status --short --branch
git -C <repo> log --oneline @{upstream}..HEAD 2>/dev/null || git -C <repo> log --oneline -10
git -C <repo> stash list
git -C <repo> worktree list
```

⚠️ Uncommitted work and stashes are the most commonly dropped item, and the most expensive. A stash the next agent doesn't know about gets popped or overwritten.

## The block

```
# Handoff: <one-line subject> (<ticket> / <branch>)

## Goal
What we are trying to achieve, in two sentences. The outcome, not the activity.

## State
- Branch, base branch, whether it is pushed, MR/PR link if one exists
- Uncommitted changes: which files, and whether they are wanted
- Stashes and worktrees, with what each one holds
- Anything running that the next agent inherits or must restart

## Done and proven
One line each, with the evidence. "Fixed X" is not done; "fixed X, `dotnet test` green,
original failing case now passes" is done.

## Done but NOT verified
Separate section, deliberately. Anything edited without the check being run.

## Remaining
Ordered. Each item is a next action, not a topic.

## Constraints and gotchas
Decisions already made and why, so they don't get relitigated. Approaches already
tried and rejected, with the reason. Anything that bit us.

## Do not
Work already done that looks undone, files that must not be touched, scope that was
explicitly ruled out.

## References
Paths and URLs only - plan documents, tickets, prior MRs, log files.
```

Drop any section that is genuinely empty. Do not pad it to look complete.

## Rules

- **Reference, don't restate.** If a plan `.html`, ticket, or design doc holds the detail, give the path. Copying it in makes the brief stale the moment the source changes.
- **Self-contained on state, external on content.** The next agent should not need this conversation, but it should read the artifacts.
- **Absolute paths.** The next agent may start in a different directory.
- **Verified and unverified are different sections.** Collapsing them is how a "done" item gets built on and fails later.
- **No narrative.** No "we then discovered", no chronology. The next agent needs the current position, not the game log.
- **Where it goes.** Chat by default, so the user can copy it. Write it to a file only if asked, and then to a scratch path, not into the repo.

## When the next agent needs different access

If the handoff exists because the next agent has something this session lacks - a running server, another repo, credentials - say so explicitly at the top, and state what it must **not** do (usually: not edit code, only observe and report). Add the response format you want back, so the reply pastes straight into the next turn here.
