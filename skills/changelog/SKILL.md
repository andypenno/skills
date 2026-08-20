---
name: changelog
description: |-
  Trigger when the user wants what changed between two points in git history written up - changelog, release notes, commits since a tag or deploy, a commit range for an MR or ticket. Not for judging a diff's quality (/code-review).
  Keywords: changelog, release notes, what changed, changes since, commits between, CHANGELOG.md, since last tag
---

# Generate Changelog

Generate a structured changelog from git history between two refs. Works across any codebase.

## Step 1 - Determine the range

Ask the user for the range if not specified. Common patterns:

| Scenario | Command |
|----------|---------|
| Between two tags | `git log v1.0.0..v1.1.0` |
| Since last tag | `git log $(git describe --tags --abbrev=0)..HEAD` |
| Between branches | `git log main..feature-branch` |
| Last N commits | `git log -n 20` |
| Between two commits | `git log abc123..def456` |

If the user says "generate a changelog" without specifying a range, use the last tag to HEAD. If there are no tags, use all commits on the current branch.

## Step 2 - Fetch the commits

Run the git log with a structured format:

```bash
git log <from>..<to> --no-merges --format="%H%x00%s%x00%b%x00%an%x00%ae" -- <path>
```

- `--no-merges` skips merge commits to avoid noise
- `%x00` (null byte) separates fields for reliable parsing
- `-- <path>` is optional - include it only if the user wants changes scoped to a specific directory (mono-repo use case)

If the range yields no commits, tell the user there are no changes and stop.

## Step 3 - Parse and filter commits

This is a **user-facing changelog**, so focus on changes that matter to end users. Apply these rules:

**Collapse dependency updates**: Any number of dependency/package update commits (e.g. `chore(deps):`, `build(deps):`, "bump X from Y to Z", "update dependencies") should be collapsed into a single bullet: `- Updated dependencies`. Never list individual package version bumps.

**Skip internal-only changes**: Omit commits that have no user-visible impact - test additions, CI config changes, linting fixes, internal refactors, code style changes. If in doubt, ask yourself: "Would a user care about this?" If no, skip it.

**Skip commits that are noise**: Build system changes, tooling updates, and developer workflow improvements should be omitted unless they directly affect users.

Categorize each remaining commit by its subject line prefix:

| Prefix | Group |
|--------|-------|
| `feat:` or `feat(...):` | Features |
| `fix:` or `fix(...):` | Bug Fixes |
| `docs:` or `docs(...):` | Documentation |
| `perf:` or `perf(...):` | Performance |
| `chore:` or `chore(...):` | Other |

### Breaking changes

A commit is a breaking change if:
- The type has a `!` suffix (e.g., `feat!:` or `feat(api)!:`)
- The commit body contains `BREAKING CHANGE:` or `BREAKING-CHANGE:`

Collect breaking changes into a separate **Breaking Changes** section that appears first.

### Non-conventional commits

Commits that don't match any prefix: if they appear user-facing (new behavior, bug fix, visible change), include them under the most appropriate group. If they're clearly internal, skip them.

## Step 4 - Extract references

Scan commit subjects and bodies for issue/PR references:
- `#123` - relative reference
- `GH-123` - GitHub-style reference
- Full URLs like `https://github.com/org/repo/pull/123`
- `JIRA-123` - Jira-style reference

Keep these references as-is in the output. If the user provides a repo URL or you can detect it from `git remote get-url origin`, convert `#123` references into full markdown links.

## Step 5 - Render the changelog

Output the changelog in markdown:

```markdown
## [v1.1.0](link) (YYYY-MM-DD)

### Breaking Changes
- **api**: Remove deprecated `/v1/users` endpoint (#45)

### Features
- **auth**: Add OAuth2 support for third-party providers (#42)
- **search**: Implement full-text search across documents (#38)

### Bug Fixes
- **payments**: Fix currency rounding error on refunds (#41)
- Fix crash when input is empty (#40)

### Documentation
- Update API reference for new auth endpoints (#43)
```

Formatting rules:
- Group header is an `###` heading
- Each entry is a bullet point
- If the commit has a scope (the part in parentheses), bold it at the start
- Include the commit description after the scope
- Append PR/issue references at the end
- Include author attribution only if the user asks for it
- Order groups: Breaking Changes, Features, Bug Fixes, then the rest alphabetically
- Within each group, sort by scope (if present), then alphabetically by description

## Step 6 - Present and save

Show the changelog to the user. If they want to save it, write it to `CHANGELOG.md` (appending above existing content) or a file of their choice.

## Mono-repo usage

When the user specifies a path (e.g., "changelog for `packages/api`"):
- Add `-- packages/api` to the git log command
- Note the scope in the changelog header: `## [v1.1.0] (YYYY-MM-DD) - packages/api`
- Only include commits that touched files in that path

## Edge cases

- **Shallow clones**: If `git log` returns fewer commits than expected, warn the user that the clone may be shallow and suggest `git fetch --unshallow`.
- **No tags exist**: Fall back to the full commit history on the current branch, or ask the user for a commit range.
- **Mixed conventional and non-conventional commits**: Categorize what you can, put the rest under "Other". Don't force-categorize ambiguous commits.
- **Very large ranges**: If there are more than 200 commits, summarize by group counts first and ask if the user wants the full detailed changelog.
