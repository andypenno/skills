# Authoring conventions

Repo-specific rules for this tree. **How** to write the prose is the `agent-authoring` skill's job - invoke it rather than restating it here.

## Two axes

Organisation is deliberately split, because the two questions have different answers.

**Domain - a reading aid only.** Engineering, Operations, Authoring, Handover, Personal. Lives in the README table. It does *not* appear in the filesystem: skills sit flat in `skills/<name>/`.

The plugin root is the repo root deliberately. Top-level `skills/` is Claude Code's default scan path *and* the flat layout other harnesses and installers expect, so no `skills` field is needed in `plugin.json` - which is what keeps this repo free of a minimum Claude Code version. Declared subdirectories are not scanned recursively, so a domain subdirectory would cost compatibility and buy nothing the model can use.

**Invocation pattern - frontmatter.** This is the axis that changes behaviour:

| Pattern | Frontmatter | Use for |
|---|---|---|
| Auto-triggered | none (default) | Anything the agent should reach for on intent. The default. |
| User only | `disable-model-invocation: true` | Expensive or deliberate work the user should choose. Currently only `qa-loop`. |
| Model only | `user-invocable: false` | Rare. Prefer leaving it discoverable. |
| File-scoped | `paths: "*.yml"` | Conventions that only apply to certain files. |

There is no "dependency" pattern. A skill invoked by another skill is a normal skill - reference it as `/skill-name` and leave it discoverable. Hiding it only hides capability.

## Naming

- Lowercase kebab-case, matching the directory name.
- Family prefix when skills share a shape: `review-correctness`, `review-simplicity`, `review-tests`. They sort together and read as a set.
- Name the job, not the implementation.

## Descriptions

Every description is a **trigger condition**, never a summary, and ends with a `Keywords:` line. Use block scalar form so it reads as prose:

```yaml
description: |-
  Trigger when <the intents that should fire it>. Also trigger when <the oblique
  phrasings>. Do NOT trigger for <the adjacent intent> (that is /other-skill).
  Keywords: <the words the user actually types, including sloppy variants>
```

The description is the entire basis for the model's load decision. Spending it on what the skill does is the most common authoring mistake in this repo's history.

## Shared contracts

Don't restate a procedure two skills need. `code-review` owns scope resolution, full-context reading, and the findings format; the review lenses say "read `/code-review` Steps 1, 2 and 4" and supply only their own checklist. One home per fact.

## Cost ceilings

Skills are loaded and re-loaded. Two ceilings are deliberate and should not drift:

- **Three review lenses.** `qa-loop` spawns one full-context subagent per lens. A fourth (`agent-authoring`) is conditional on the diff touching agent-facing text. Adding a permanent fourth lens needs a reason better than completeness.
- **Body length.** If a `SKILL.md` needs long references, templates, or examples, they go in sibling files the skill points at, not in the body.

## Bundled files

Anything shipped alongside a `SKILL.md` (`examples/`, templates, scripts) must be found, not hardcoded - the same skill lands in `~/.claude/plugins/…` under a plugin install, `~/.claude/skills/…` under a copy, and `~/.agents/skills/…` under the Codex/opencode symlink. See how `reflect` locates its extractor.

Scripts must run on bash 3.2 (macOS ships it - no `declare -A`) and use only widely available tools. `grep`/`find` are correct *inside* committed scripts even though `rg`/`fd` are correct when driving this machine.

## Before pushing

```sh
claude plugin validate .
```

Then re-read the rendered `SKILL.md` top to bottom, and check the description fires on the phrasings you actually use and stays quiet on its neighbours.
