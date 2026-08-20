---
name: hooks
description: |-
  Trigger when setting up, debugging or changing a verification hook - a git pre-commit or pre-push hook, or a Claude Code Stop / PreToolUse hook. Also when a hook never fires, fires twice, cannot be turned off, loops the agent, hangs a turn, or floods the context with build output.
  Keywords: hook, hooks, pre-commit, pre-push, git hook, stop hook, pre-stop, PreToolUse, hooksPath, hook not firing, hook loop, disable the hook, hook timeout
---

# Hooks

Automated verification that the harness or git runs for you. Getting one to *run* is easy; the failures below are what makes them painful, and every one has bitten a real repo.

For the `settings.json` mechanics themselves - which keys, which scope, matcher syntax - use `/update-config`. This skill is about what to put in the hook and why.

## Pick the hook by what it can afford

| Hook | Budget | Runs | Blocks on non-zero |
|---|---|---|---|
| git `pre-commit` | ~seconds | Format/lint the **staged** files only. No build, no tests. | The commit |
| git `pre-push` | ~tens of seconds | Build, then test. | The push |
| Claude `Stop` | up to its configured timeout | Whatever proves the turn's work. Its output is read by the model. | Nothing - see exit codes |
| Claude `PreToolUse` | milliseconds | Allow/deny or rewrite a tool call. | The tool call |

A hook that costs more than the mistake it catches gets disabled within a week. Scope it to what changed, not the whole repo.

## Install

**Git hooks** go in a tracked directory, not `.git/hooks` (which is per-clone and un-reviewable):

```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
```

Put the logic in a sourced `lib.sh` and keep each hook thin. Three hooks sharing one behaviour is three chances to drift; one library with three entry points is not.

⚠️ Add `.githooks/** text eol=lf` to `.gitattributes`. A CRLF hook fails with `bad interpreter: /bin/sh^M`, and `.gitattributes` only fixes **new** checkouts - an existing Windows clone keeps its CRLF blobs and `--renormalize` will not help. Fix it by deleting the tracked hook files and restoring them once.

**Claude hooks** go in `settings.json` with a script under `.claude/hooks/`. Set `timeout` explicitly; the default is not generous enough for a build.

## Exit codes are the whole contract

| Hook | Exit 0 | Non-zero |
|---|---|---|
| git hooks | proceed | abort the operation, stderr shown to the user |
| Claude `Stop` | release the turn | **2 = feed stderr back to the model and reprompt it**; other non-zero is an error |
| Claude `PreToolUse` | allow | 2 = deny and tell the model why |

🧨 The `Stop` hook's exit 2 is a loop. An unfixable environment - no network, missing SDK, a genuinely broken test - reprompts forever, burning tokens until the user kills it. **Every exit-2 path needs a release valve**: count consecutive identical failures in a stamp file, and after two or three, report the problem and `exit 0` instead. Reset the counter on release, so a still-broken tree gets reported again next turn rather than silently passing for ever.

## Output is context, so squash it

A `Stop` hook's output goes into the model's context and is charged for. A failed build prints thousands of lines around a handful of diagnostics.

- Keep the diagnostics; drop project suffixes, doc URLs, runner frames, passing suites.
- Measured on a real repo: build failure 4025 → 565 bytes, four test failures 3321 → 1223.
- **If the squash matches nothing** - crashed test host, aborted run - print the raw tail instead. "Failed" with no evidence is worse than a few noisy lines.

Prefer a deterministic fixer over reporting where one exists. Running the formatter costs seconds; making the model fix formatting costs a whole reprompt.

## Timeouts

Stock macOS has no `timeout(1)`, and `perl`'s `alarm` kills only the direct child, orphaning the test host.

The portable shape: re-exec the script's verification body as a child under job control so it gets **its own process group**, start a `sleep`-based watchdog beside it, and kill the negative PID so the whole tree dies. Trap `TERM`/`INT` to take down both groups, or an outside kill leaves the build tree and the watchdog's sleep behind. Nothing can trap `SIGKILL` - accept that it orphans.

Keep the script's own budget **below** the hook's `timeout` in `settings.json`, and say so in a comment. Raising one without the other silently changes which layer kills the run.

## Make repeat runs cheap

Hash the inputs - changed-file contents, their path list, `HEAD`, and **the hashes of the hook and its library** - into a stamp file. Identical hash means the previous pass still holds, so an unchanged tree costs a fraction of a full run.

Including the hook's own hash is the part people miss: without it, editing the verification logic leaves stale passes trusted under new rules.

Take a lock if two triggers can overlap (a push during a `Stop` run will collide over build output). A lock directory with a pid file inside, plus a grace period before treating a pid-less lock as abandoned, avoids a racing run stealing a live lock.

## Turning it off

⚠️ Settings files **merge** their hooks rather than overriding them. Redefining a hook in `settings.local.json` does not replace it - both copies run.

Build the off-switch into the script instead: an env var like `HOOK_SKIP_VERIFY=1` to skip, another to change the budget, and ship a `settings.local.json.example` documenting them.

## Verify it before trusting it

A hook is a branch-heavy script that runs when you are least able to debug it. Do not ship one from reading.

1. Introduce each failure class deliberately - one at a time - and confirm what comes back: format failure, build error, test failure, timeout, missing toolchain, unloadable workspace.
2. Confirm the clean case exits 0 and is fast on a second run (the stamp works).
3. Confirm the release valve fires: force the same failure repeatedly and check the turn is released rather than looping.
4. Run `shellcheck` on it, and `bash -n` / `sh -n` at minimum.

Also test the case where the tool is missing entirely. A hook that reports "formatting failed" when the real problem is an unrestored workspace sends the next person after the wrong bug - detect that case and report it as what it is.
