---
name: watch-ci
disable-model-invocation: true
description: |-
  Trigger when the user wants CI on a PR or MR followed to a conclusion - watch the pipeline, tell me when it goes green, is it done yet, did the checks pass, get the failing job's log, rerun the failed jobs. Works on GitHub and GitLab including self-hosted. For diagnosing why a pipeline broke, use /triage.
  Keywords: watch ci, watch the pipeline, wait for checks, did CI pass, is the pipeline green, pipeline status, failing job log, rerun failed jobs, retry the pipeline, checks still running, babysit the MR
---

# Watch CI

Follow checks to a terminal state, then report. The two hosts are not symmetric: **GitHub has a scriptable gate, GitLab does not**, so the poll loop is yours to own on GitLab.

## Step 1 - Resolve the host

Do not guess from the hostname. A self-hosted GitLab instance often has nothing in its hostname that says "gitlab".

```bash
git config --get remote.origin.url        # github.com -> gh; otherwise cross-check:
glab auth status --all                    # is this host a configured GitLab instance?
```

`gh` fails closed on a non-GitHub remote (`none of the git remotes ... point to a known GitHub host`, exit 1), which is itself a usable signal.

## Step 2 - Resolve the PR/MR and its pipeline

| | GitHub | GitLab |
|---|---|---|
| Infer from branch | `gh pr checks`, `gh pr view` infer it | `glab mr view` infers it |
| Get the number | `gh pr view --json number -q .number` | `glab mr view -F json --jq .iid` |

⚠️ **`glab mr view` silently returns a closed or merged MR** for the branch. Always assert `.state == "opened"` before acting on it.

🧨 **Self-hosted GitLab: MR pipelines run on `refs/merge-requests/<iid>/head`, not the branch.** `glab ci status -b <branch>` resolves the latest pipeline for that ref and can report `success` while the MR's actual head pipeline failed. Verified. Always go through the MR:

```bash
glab api projects/:fullpath/merge_requests/<iid> --jq .head_pipeline.id
glab ci get -p <that-id> -F json
```

Also: `gh pr checks -R owner/repo` **requires** an explicit PR argument.

## Step 3 - Watch

**GitHub** - native blocking gate, and the exit code is the answer:

```bash
gh pr checks --watch          # 0 = pass, 1 = failure, 8 = still pending
gh pr checks --watch --fail-fast
```

- `--interval` and `--fail-fast` are rejected **without** `--watch`.
- `--watch` with `--json` is a hard error.
- 🧨 **`gh pr checks --json …` always exits 0**, even on failure - the exporter returns before the exit-code logic. In JSON mode you must parse `bucket` (`pass|fail|pending|skipping|cancel`). Never gate on the exit code of a JSON call.
- `gh pr checks` exits 1 for `no checks reported on the '<branch>' branch` too, which is indistinguishable from a real failure by exit code alone. Check stderr or count from JSON.
- `gh run watch <run-id> --exit-status` is the run-level alternative; it **requires a run id non-interactively**, and does not work with fine-grained PATs.

**GitLab** - no exit-code signal exists anywhere in the read paths. `glab ci status`, `--live` and `ci get` all exit 0 on a failed pipeline. Poll and parse:

```bash
# --wait is absent from some installed versions (1.103.0) though it is in the docs.
glab ci status --help | rg -q -- '--wait' && HAVE_WAIT=1

while :; do
  status=$(glab ci get -p "$PIPELINE_ID" -F json --jq .status)
  case "$status" in
    success|failed|canceled|skipped|manual) break ;;
  esac
  sleep 20
done
```

⚠️ **Two different JSON schemas for the same data.** `glab ci status -F json` is wrapped (`.pipeline.status`); `glab ci get -F json` and `glab ci get --merge-request=<iid>` are **flat** (`.status`). Querying `.pipeline.status` against the flat shape yields `null` with exit 0 - a silent-empty trap.

## Step 4 - Get the failure, cheaply

Logs are the expensive part. Fetch the failing job only, and tail it.

**Identify the failing jobs first:**

```bash
# GitHub
gh run view <run-id> --json jobs --jq '.jobs[]|select(.conclusion=="failure")|{name,databaseId}'
# GitLab
glab ci get -p <id> -F json --jq '[.jobs[]|select(.status=="failed")|{id,name,stage}]'
```

**Then the log:**

| GitHub | GitLab |
|---|---|
| `gh run view <run-id> --log-failed` | no failed-only mode exists |
| `gh api repos/{owner}/{repo}/actions/jobs/<job_id>/logs \| tail -n 50` | `glab api projects/:fullpath/jobs/<job_id>/trace \| tail -n 50` |

Neither CLI can limit output natively - pipe to `tail`. `gh run view --log` can silently fall back to per-job API fetches and hard-fails past 25 missing job logs.

⚠️ Never run `glab ci view` (full TUI) or `glab ci trace`/`glab ci retry` **without an argument** (they go interactive). Neither is safe from a script.

## Step 5 - Retry or report

| | GitHub | GitLab |
|---|---|---|
| Rerun failed only | `gh run rerun <run-id> --failed` | `glab api -X POST projects/:fullpath/pipelines/<id>/retry` |
| Rerun one job | `gh run rerun <run-id> --job <databaseId>` | `glab ci retry <job-id>` |

The `<number>` in a browser job URL is **not** GitHub's `--job` value - use `databaseId` or get a 404.

⚠️ A retry is a stateful action. Retry unasked only to distinguish a flake from a real failure, say that is why, and never more than once. A green-on-retry result is a **flake finding**, not a pass - report it as one.

## Report

- Verdict, and the evidence: which checks, which job, terminal status
- For a failure: the job name and the relevant log lines, not the whole trace
- Whether it is a flake (passed on retry) or real
- On GitLab, state which pipeline id you watched and that it was the MR head pipeline - the branch-versus-MR-ref trap is invisible in the output

Diagnosing *why* it broke is `/triage` (CI mode). This skill establishes what failed and hands over.
