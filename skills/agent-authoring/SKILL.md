---
name: agent-authoring
description: |-
  Trigger before writing the prompt for an agent you are about to spawn - "spin up N subagents to", "write a prompt for the agent to", "get some subagents to". Also before writing or editing any other text an agent reads: SKILL.md, CLAUDE.md, AGENTS.md, MCP tool descriptions. Also when an instruction is being ignored, a skill isn't firing, a rule may sit in the wrong file, or instruction files need trimming or reordering. Do NOT trigger to review a code diff (that is /review-full, which spawns this as the lens for agent-facing text). For a prompt carried to another system use /agent-brief; for one pasted into a fresh session use /handoff.
  Keywords: subagent prompt, spawn prompt, spin up subagents, write a prompt for the agent, roster of agents, skill, SKILL.md, CLAUDE.md, AGENTS.md, instructions file, agent instructions, tool description, why isn't this skill triggering, where should this rule live
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
  Do NOT trigger to judge the quality of a diff (that is /review-full).
  Keywords: changelog, release notes, what changed, since last tag

# ❌ summary-shaped
description: "Generates a structured changelog from git history between two refs."
```

Include: the phrasings that should fire it, the adjacent intents that should *not*, the sibling skill to prefer instead, and a `Keywords:` final line.

**2. Editing instructions is not additive.**

The reflex is to append. Often the correct change is to **delete an offending line** or **rewrite an existing one** - a contradicting rule is worse than a missing one, because the agent picks whichever it saw last. Before adding anything, find what already covers the topic and decide whether to replace it.

**3. Every fact appears exactly once.**

Duplicated rules cost tokens on every turn and drift out of sync. If two files state a rule, one of them is wrong and you won't know which. Put it in the most specific file that owns the topic and reference it from anywhere else.

## Writing a spawn prompt

A subagent inherits nothing - not the conversation, not what you have already ruled out, not your instruction files beyond its own. The prompt is the whole world it gets.

- **Scope, not framing, for an independent reviewer.** The task and where to look. Never what you suspect or what a previous round found. A reviewer told what to expect confirms you instead of testing you, and on a repeated round it turns independent agents into copies of the last one. A stage whose job is to check or merge earlier output gets that output as its task.
- **What it can reach.** Absolute repo path, MCP server or workspace, and which credentials it has. It cannot infer any of these, and it will fabricate a path rather than ask.
- **No nesting.** "Do not spawn subagents. Do all the work yourself." Fan-out from a child is invisible to you and uncapped.
- **Read-only unless editing is the task.** Agents running side by side share one working tree, so one that edits it (a mutation test, a trial fix) corrupts what the others read. Such work goes in a `git worktree`.
- **Its own pass/fail criteria.** Stated in the prompt, or named by the skill that owns them, so the agent returns a verdict rather than an impression for you to grade.
- **The reply shape, verbatim.** Give the exact headings or fields. One fenced block with nothing outside it when the user will paste the reply onward.

## Routing a rule to the right file

Discover the files before assuming them - never assume a root `CLAUDE.md` exists:

```bash
fd -HI -E node_modules -E worktrees -i '^(claude|agents)(\.local)?\.md$' <repo-root>
```

| The rule is about… | Where it goes |
|---|---|
| How the user works across every repo (tone, verification habits, tool preferences) | personal `~/.claude/CLAUDE.md` |
| A repo-wide convention every contributor needs | the repo's existing root instruction file - whichever convention it already uses |
| One area of the repo (a tests dir, a service, a tool folder) | the instruction file nearest that code |
| Project-specific but personal, not for teammates | `<repo>/CLAUDE.local.md`, gitignored |
| Overriding a harness default | personal `CLAUDE.md` - it is Claude-specific, so it must not go in `AGENTS.md` |
| A file generated from a template | the template, never the generated file - edit the source or the next generation reverts you |

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

## Reporting

As a review lens, each finding is `path:line`, the broken instruction, what it conflicts with or the missing target it names, and the replacement text.

## Verdict

When run as a review lens, end with one line: `VERDICT: PASS` or `VERDICT: FAIL`. This judgement is yours, not the caller's.

`FAIL` only on a Critical or Warning. In this lens that means:

- A referenced file, path, or skill does not exist (Critical - the instruction cannot be followed)
- A rule contradicts one already present in another instruction file in scope (Critical - the agent cannot obey both)
- A description summarises what the skill does instead of when to trigger it, or has no keywords line (Warning - the skill will not load)
- A rule silently duplicates one that already has a home elsewhere (Warning)
- The edit was purely additive where replacing or deleting an existing line was the correct change (Warning)
- The edit breaks an authoring convention the repo states, in an instruction file or a conventions doc (Warning)

`PASS` otherwise, and a `PASS` may carry Suggestions. Padding, a restating opener, an Overview/Conclusion shell, a sentence whose deletion loses nothing, wording you would have phrased differently: report them as Suggestions and pass. Prose you dislike is not a broken instruction.
