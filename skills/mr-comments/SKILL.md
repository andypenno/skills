---
name: mr-comments
description: |-
  Trigger when review feedback on a PR or MR needs reading or acting on - address the review comments, fix the MR comments, what did the reviewer ask for, are there unresolved threads, reply to the review. Works on GitHub and GitLab including self-hosted. For following the PR/MR over time use /watch-mr.
  Keywords: review comments, MR comments, PR comments, address the feedback, fix review comments, unresolved threads, what did the reviewer say, resolve the thread, reply to the review, reviewer asked for
---

# MR Comments

Read review feedback, act on it, and close the loop. The two hosts diverge more here than anywhere else - **resolved state on GitHub is GraphQL-only, and on GitLab it is plain REST**. There is no single code path; write two.

Host detection and PR/MR resolution: `/watch-ci` Step 1 and Step 2. The `.state == "opened"` assertion on GitLab matters here too.

## Fetching - the trap first

🧨 **`gh pr view --json comments` silently omits every inline comment.** So does `gh pr view -c`. A PR with ten line comments and no issue comments reports as having no feedback. Inline comments live only in `pulls/N/comments` or GraphQL.

**GitHub** needs two calls - GraphQL for thread identity and resolved state, REST if you want the diff hunk:

```bash
gh api graphql -f owner=OWNER -f repo=REPO -F number=N -f query='
query($owner:String!,$repo:String!,$number:Int!){
  repository(owner:$owner,name:$repo){ pullRequest(number:$number){
    reviewThreads(first:100){ totalCount pageInfo{hasNextPage endCursor}
      nodes{ id isResolved isOutdated path line startLine diffSide subjectType
             comments(first:50){ nodes{ databaseId author{login} body diffHunk } } } } } }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

⚠️ `reviewThreads(first:100)` is a hard cap and the nested `comments(first:)` paginates **independently** - long threads truncate silently. Check `pageInfo.hasNextPage` and `totalCount` rather than assuming you got everything.

**GitLab** gets everything in one call, and has an unresolved filter built in:

```bash
glab mr note list N --state unresolved -F json      # also --type diff|general|system, --file <path>
```

Raw equivalent when you need the discussion ids:

```bash
glab api "projects/:fullpath/merge_requests/N/discussions?per_page=100" --paginate \
  --jq '.[] | select(.resolvable == true and .resolved == false)
        | {id, path: .notes[0].position.new_path, line: .notes[0].position.new_line,
           author: .notes[0].author.username, body: .notes[0].body}'
```

⚠️ Use `/discussions`, never `/notes` - notes carry **no `discussion_id`**, so a note fetched that way can neither be replied to in-thread nor resolved. Also `glab mr view -F json` does **not** include comments, even with `--comments`; those flags only change text output.

Comment kinds: GitLab discriminates on `notes[].type` - `DiffNote` inline, `DiscussionNote` threaded top-level, `null` plain. **Filter out `system: true`** or you will "address" GitLab's own "changed this line in version 3" notes.

## Reading the code before fixing

For each unresolved thread, read the **file at the commented line**, not just the comment. A reviewer's one-line remark usually points at a problem larger or smaller than it appears.

GitHub hands you `diffHunk` free. GitLab gives line numbers and SHAs only - no hunk - so fetch context yourself if you intend to quote it.

Then, before editing: list each comment, your reading of what it asks, and what you plan to change. Ambiguous feedback resolved by guessing is how a second review round happens.

## Fixing

- **One commit per comment**, so the reviewer can follow the response to each point.
- Code changes only. Do not restructure surrounding code because you are in the area - that expands the diff the reviewer already reviewed.
- If you disagree with a comment, do not silently comply and do not silently ignore it. Say so, with the reason, and let the user decide.
- A comment that reveals a class of problem: fix the instance asked for, and **report the siblings** rather than fixing them unasked. See `/review-correctness` for the sweep.

## Replying and resolving

| | GitHub | GitLab |
|---|---|---|
| Reply in thread | no CLI - `gh api -X POST repos/{o}/{r}/pulls/N/comments/{comment_id}/replies -f body='…'` | `glab mr note create N --reply <discussion-id> -m '…'` |
| New inline comment | `gh api -X POST repos/{o}/{r}/pulls/N/comments -f body=… -f commit_id=SHA -f path=… -F line=42 -f side=RIGHT` | `glab mr note create N --file <path> --line 42 -m '…'` |
| Mark resolved | **no CLI and no REST** - GraphQL `resolveReviewThread(input:{threadId:"PRRT_…"})`, needs the node id from the query above | `glab mr note resolve <discussion-id> [N]` |
| Non-blocking note | n/a | `glab mr note create N -m '…' --resolvable=false` |

⚠️ Posting and resolving are outward-facing and visible to colleagues. Do not do either on your own initiative - make the code changes, then show the user the replies you propose and let them send them.

⚠️ Interactive traps that hang a non-interactive run: `gh pr review` with no flags prompts; `gh pr comment` with no `-b`/`-F` opens an editor; `glab mr note create` with no `-m` opens an editor. Every `glab mr note *` subcommand is marked EXPERIMENTAL in 1.103.0 - `glab api` is the stable fallback.

## Report

Per thread: author, file and line, what they asked, what you changed, and the commit. Then separately: threads you did **not** action and why, threads you disagree with, and anything whose intent you could not determine. Close with which threads are still open - on GitHub state that resolved status came from GraphQL, since a REST-only reading cannot see it at all.
