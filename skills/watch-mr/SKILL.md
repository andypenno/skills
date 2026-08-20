---
name: watch-mr
disable-model-invocation: true
description: |-
  Trigger when an open PR or MR needs following over time rather than a one-off check - watch the MR, tell me when it's ready to merge, babysit this PR, has anyone reviewed it, what's changed on the MR, why can't this merge yet. Delegates to /watch-ci for pipelines and /mr-comments for review feedback.
  Keywords: watch the MR, watch the PR, babysit the MR, is it ready to merge, why can't it merge, what changed on the MR, any new comments, has it been approved, merge readiness, shepherd the PR
---

# Watch MR

Follow an open PR/MR until it is mergeable, reporting only what **changed** since the last look. The loop and the merge-readiness gate live here; the pipeline detail is `/watch-ci` and the review feedback is `/mr-comments`.

Host detection and PR/MR resolution: `/watch-ci` Steps 1 and 2, including the `.state == "opened"` assertion on GitLab.

## The merge-readiness gate

This is the one question the loop exists to answer, and the two hosts express it completely differently.

**GitHub** - two orthogonal fields, and you need both:

```bash
gh pr view N --json mergeable,mergeStateStatus,isDraft,reviewDecision
```

| `mergeStateStatus` | Meaning |
|---|---|
| `CLEAN` | mergeable, checks passing |
| `BLOCKED` | a required review, check or ruleset blocks it |
| `BEHIND` | head is out of date with base |
| `DIRTY` | conflicts - no merge commit possible |
| `UNSTABLE` | mergeable, but a commit status is failing |
| `HAS_HOOKS` | mergeable and passing, pre-receive hooks apply |
| `UNKNOWN` | still being computed |

⚠️ GitHub collapses every *reason* into `BLOCKED`. To say **why**, fetch `reviewDecision`, the checks, and thread state separately.

**GitLab** - one field that names the blocker:

```bash
glab mr view N -F json --jq '{detailed_merge_status, draft, has_conflicts, blocking_discussions_resolved, can_merge: .user.can_merge}'
```

`mergeable` means it can merge now. Otherwise the value *is* the reason: `not_approved`, `discussions_not_resolved`, `ci_must_pass`, `ci_still_running`, `conflict`, `need_rebase`, `draft_status`, `requested_changes`, `blocked_status`, `external_status_checks`, `merge_time`, `preparing`, `checking`, and more.

🧨 **Never branch on GitLab's `merge_status`.** It is deprecated and it lies - verified on a real MR reporting `merge_status: "can_be_merged"` while `detailed_merge_status` was `not_approved`.

⚠️ The enum is version-scoped: newer instances add values older ones lack. Treat an unrecognised value as **blocked, reason unknown** rather than failing or assuming mergeable.

## Approvals

| GitHub | GitLab |
|---|---|
| `reviewDecision` ∈ `APPROVED` / `CHANGES_REQUESTED` / `REVIEW_REQUIRED` / `null` | `glab api "projects/:fullpath/merge_requests/N/approvals"` → `approvals_required`, `approvals_left`, `approved_by[].user.username` |
| Who: `--jq '[.latestReviews[]\|select(.state=="APPROVED").author.login]'` | Per-rule detail: `glab mr approvers N -F json` |

⚠️ `reviewDecision: null` means the repo requires no reviews - **not** "not approved". On GitLab, `approvals_before_merge` on the MR object is deprecated and returns `null`; read `/approvals`. Approval *rules* are an EE/Premium feature - `rules[]` comes back empty on gitlab.com Free.

## The poll loop

Report deltas, not full state. A loop that reprints everything each cycle is unreadable.

**Cheap change detection:**

| GitHub | GitLab |
|---|---|
| `gh api "repos/{o}/{r}/pulls/N/comments?since=TS&sort=updated&direction=desc"` | ❌ no `since` on discussions - gate on the MR object first: `updated_at` and `user_notes_count`, then filter notes client-side |
| Everything: `gh api "repos/{o}/{r}/issues/N/timeline?per_page=100" --paginate` | `glab mr note list N --type system -F json` |

Both hosts support ETag revalidation - send `If-None-Match` and a 304 means nothing changed.

🧨 **Both `gh api` and `glab api` exit 1 on a 304.** A poll loop that treats non-zero as failure will abort on the first unchanged cycle. Distinguish 304 from a real error before acting on the exit code.

Poll on a sane interval (30-60s), and state the interval when you start. Stop conditions, all of them reportable:

- Mergeable - the goal
- A blocker that needs the user (approval required, changes requested, conflicts)
- Nothing changed for a long stretch - say so and ask whether to keep waiting rather than looping silently
- The user's own stop

## Each cycle

1. **Merge readiness** - the gate above. If mergeable, stop and say so.
2. **New review activity** - if there are new or still-unresolved threads, hand to `/mr-comments`. Do not summarise review feedback yourself; the trap where GitHub's inline comments are invisible to `gh pr view` lives in that skill.
3. **CI transitions** - hand to `/watch-ci`. Only report a change of state, not that it is still running.
4. **Structural changes** - draft toggled, base moved, force-push, new commits, conflicts appearing.

## Merging

⚠️ Merging is irreversible and outward-facing. Never merge on your own initiative, even when the gate says `CLEAN`/`mergeable` - report that it is ready and stop.

If the user does ask: `glab mr merge` **defaults to `--auto-merge=true` when a pipeline is running**, so it silently queues instead of merging. Pass `--auto-merge=false` for an immediate merge, and `-y` to avoid its prompt.

## Report

Lead with the verdict and, when blocked, the *specific* blocker - on GitLab quote `detailed_merge_status`, on GitHub name which of review/checks/threads is responsible rather than repeating `BLOCKED`. Then the delta since last cycle. Then what needs a human.
