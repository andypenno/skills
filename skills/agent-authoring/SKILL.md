---
name: agent-authoring
description: |-
  Trigger before writing or editing text an agent reads - SKILL.md, CLAUDE.md, AGENTS.md, MCP tool descriptions, subagent prompts. Also when an instruction is being ignored, a skill isn't firing, a rule may sit in the wrong file, or instruction files need trimming or reordering.
  Keywords: skill, SKILL.md, CLAUDE.md, AGENTS.md, instructions file, agent instructions, tool description, subagent prompt, why isn't this skill triggering, where should this rule live
---

# Agent Authoring

Text an agent reads is code, and it is loaded on every turn that touches it. It is priced per token, read literally, and obeyed selectively. Write it accordingly.

## The three rules that matter most

**1. A description is a trigger condition, not a summary.**

The description is the only part the model sees before deciding whether to load the skill. Describing *what the skill does* wastes that budget; describe *when to reach for it*, including the near-misses that should not fire it. Close with a keywords line so imperfect phrasings still match.

```yaml
# ✅ trigger-shaped
description: |-
  Trigger when the user wants to know what changed between two points in git history…
  Do NOT trigger to judge the quality of a diff (that is /code-review).
  Keywords: changelog, release notes, what changed, since last tag

# ❌ summary-shaped
description: "Generates a structured changelog from git history between two refs."
```

Include: the phrasings that should fire it, the adjacent intents that should *not*, the sibling skill to prefer instead, and a `Keywords:` final line.

**2. Editing instructions is not additive.**

The reflex is to append. Often the correct change is to **delete an offending line** or **rewrite an existing one** - a contradicting rule is worse than a missing one, because the agent picks whichever it saw last. Before adding anything, find what already covers the topic and decide whether to replace it.

**3. Every fact appears exactly once.**

Duplicated rules cost tokens on every turn and drift out of sync. If two files state a rule, one of them is wrong and you won't know which. Put it in the most specific file that owns the topic and reference it from anywhere else.

## Routing a rule to the right file

Discover the files before assuming them - never assume a root `CLAUDE.md` exists:

```bash
fd -H -i '^(claude|agents)(\.local)?\.md$' <repo-root>
```

| The rule is about… | Where it goes |
|---|---|
| How the user works across every repo (tone, verification habits, tool preferences) | personal `~/.claude/CLAUDE.md` |
| A repo-wide convention every contributor needs | the repo's existing root instruction file - whichever convention it already uses |
| One area of the repo (a tests dir, a service, a tool folder) | the instruction file nearest that code |
| Project-specific but personal, not for teammates | `<repo>/CLAUDE.local.md`, gitignored |
| Overriding a harness default | personal `CLAUDE.md` - it is Claude-specific, so it must not go in `AGENTS.md` |

⚠️ `AGENTS.md` is shared with other agent tools. Keep it tool-agnostic; Claude-only behaviour belongs in `CLAUDE.md`.

## Writing the body

- **Imperative and specific.** "Prefer `rg`" is advice. "`grep` is permission-denied on this machine; use `rg`" is a rule with a reason, and it survives paraphrase.
- **Give the why when it changes behaviour under novelty.** A rule with no reason gets misapplied at the first edge case. A rule with a war story attached is bloat. One clause.
- **Structure over prose.** Three or more comparable items is a table or a list. Prose forces the reader to hold state; you are writing for something that skims.
- **Name the failure the rule prevents.** Rules that describe a good outcome are ignored; rules that describe the mistake are not.
- **Say what NOT to do.** Negative boundaries are followed more reliably than positive aspirations, and they are what stop over-reach.
- **Progressive disclosure.** The `SKILL.md` body holds what is needed every time. Long references, templates, and examples go in sibling files the skill points at.

## Anti-slop

The failure mode is not exotic vocabulary, it is padding:

- No opener that restates the prompt or announces what the document will cover. Start with the content.
- No reflexive section scaffolding - Overview / Background / Key Takeaways / Conclusion added because documents have those.
- No sentence whose deletion loses nothing. Puffery ("robust", "comprehensive", "seamless"), significance inflation ("it is crucial to note"), and hedging that commits to nothing.
- No history, dates, or narration of the change. That is commit material. Instruction text reads identically whether a stranger wrote it a year ago.
- No restating a rule for emphasis. Repetition reads as two rules and dilutes both.

## Frontmatter that actually does something

| Field | Effect |
|---|---|
| `name`, `description` | Required. The description carries the whole trigger decision. |
| `disable-model-invocation: true` | User-only: the model cannot fire it. Use for expensive or destructive skills the user should choose deliberately. |
| `user-invocable: false` | Model-only: hidden from the `/` menu. |
| `allowed-tools` / `disallowed-tools` | Constrain the tools available while the skill runs. |
| `model`, `effort` | Override for this skill's turn. |
| `context: fork` + `agent` | Run in an isolated subagent. |
| `paths` | Auto-load only when matching files are in play. |

A skill referenced by another skill is still a normal skill - write `/skill-name` and let the agent load it. There is no dependency mechanism, and inventing one with unreachable helper skills just hides capability.

## Before you finish

1. Re-read the **rendered** file top to bottom, not your diff. Is the order sensible, is anything now said twice, is any section unreachable or contradicted later?
2. For a skill: does the description fire on the phrasings the user actually uses, and stay quiet on the neighbours?
3. Did anything get longer without getting clearer? If so, cut it back.

## Verdict

When invoked as a review lens by `/qa-loop`, end with one line: `VERDICT: PASS` or `VERDICT: FAIL`. This judgement is yours, not the caller's.

`FAIL` if any of these hold in the text under review:

- A description summarises what the skill does instead of when to trigger it, or has no keywords line
- A rule contradicts, or silently duplicates, one already present in another instruction file in scope
- The edit was purely additive where replacing or deleting an existing line was the correct change
- A referenced file, path, or skill does not exist
- Boilerplate scaffolding or padding was added: a restating opener, an Overview/Conclusion shell, or a sentence whose deletion loses nothing

`PASS` if none hold.
