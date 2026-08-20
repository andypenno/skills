---
name: docs-audit
disable-model-invocation: true
description: |-
  Trigger when documentation needs checking rather than writing - the user asks whether docs are outdated, wrong, or missing anything, wants a README or doc reviewed, or says a doc is too developer-focused, too long, or written for the wrong reader. Also after renaming a concept or dropping a feature, when docs still describe the old world.
  Keywords: docs review, review the readme, is anything outdated, stale docs, docs are wrong, too developer coded, user focused, rewrite the readme, doc audit, still talks about, out of date documentation
---

# Docs Audit

Two passes over every doc in scope: **who is it for**, and **is it still true**. They always arrive as one complaint, so do both.

Enumerate first - never audit only the file that was mentioned:

```bash
fd -H -e md -e mdx . <repo-root> --exclude node_modules
```

## Pass 1 - Audience

For each doc, name its reader in one word, then check the first screen serves them.

| Doc | Reader | First screen owes them |
|---|---|---|
| README | someone deciding whether to use it | what it is, what it does for them, how to set it up |
| Setup/install guide | someone with a terminal open | prerequisites and the happy path, in order |
| Reference | someone who already committed | precise, complete, skimmable |
| Contributing / architecture | a contributor | how to build, test, and where things live |
| `CLAUDE.md` / `AGENTS.md` | an agent | see `/agent-authoring` - different rules entirely |

⚠️ The default failure is a README written as a developer diary: development philosophy, how to run the tests, design rationale, contribution rules. Those have a reader, but not this one. Move them to the doc that owes them; do not delete them.

For a private or personal repo the README doubles as the live inventory of what exists right now. Treat drift there as a defect, not cosmetics.

## Pass 2 - Staleness

Check the doc's claims against the tree, not against your memory of the tree. Every one of these is a real, repeated failure:

- **Renamed concepts** still referenced by their old name
- **Removed features or services** still listed, or still described as available
- **Reversed decisions** - a doc explaining the approach abandoned three commits ago
- **Features listed as done that are partial** - demote them and mark them partial rather than deleting the row
- **Version numbers, badges and pinned versions** that no longer match the manifests
- **Paths, commands and file names** that no longer resolve. Check them, do not eyeball them.
- **Instructions that no longer work** - if a doc gives a command, run it or say you did not

```bash
rg -n '<the old name>' --glob '*.md'      # the concept that got renamed
rg -n '<command or path from the doc>'    # does the thing it tells you to run exist
```

## Fixing

- **Edit in place.** Do not append a "Notes" or "Updates" section - that is how docs get twice as long and half as true.
- **Compress while you are there.** Docs are read repeatedly and paid for repeatedly: state each fact once, cut the section that exists only because documents have that section.
- **Only what you verified.** If you could not check a claim, leave it and list it as unverified rather than rewording it into confidence.
- Match the file's existing voice and structure.

## Report

Group by file. Per finding: audience mismatch or staleness, the evidence, and the fix applied. Close with what you could **not** verify, and any doc you judged fine - "no changes needed" is a valid result and stops the next pass re-reading it.
