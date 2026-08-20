---
name: reflect
description: |-
  Trigger when the user wants to learn from past sessions rather than from code - what they keep correcting, what friction recurs, or instruction files improved from evidence. Also when they complain about repeating themselves or an instruction being ignored across sessions. Not for authoring instruction files from scratch (/agent-authoring).
  Keywords: reflect, learn from my sessions, what do I keep correcting, session history, transcripts, recurring friction, self-improve CLAUDE.md
---

# Reflect - learn from your own session history

Every session is feedback. This skill harvests it: it mines the user's Claude Code transcripts for **recurring** friction (corrections they make again and again, interruptions, instructions repeated across sessions) and turns that into concrete, evidence-backed edits to whichever `CLAUDE.md` should carry the rule. The result is a self-improving loop - the assistant gets told, once and in the right place, what the user keeps having to say.

Works for a single project or the user's entire history, and routes each improvement to the file where it belongs: personal, project-shared, or project-local.

## What is fixed vs. what is dynamic

- **Fixed (deterministic):** data extraction. A bundled script collapses the raw transcripts (often gigabytes of JSONL) into a small corpus of just the user's typed words. You want the *same* corpus every run, so this never varies.
- **Dynamic (authored fresh each run):** the analysis. You write a new multi-agent **Workflow** every time you invoke this skill. This is deliberate - re-running `reflect` should surface *new* angles, not reprint an identical list. Vary the analytical lenses and the prompts between runs.

Invoking this skill **is** the user's opt-in to spawn a Workflow. Do not ask whether to use one - author it.

## Step 1 - Scope the sessions

Claude Code stores per-project transcripts at `~/.claude/projects/<slug>/`, where `<slug>` is the project's absolute path with every `/` replaced by `-` (e.g. `/Users/me/Workspace/foo` → `-Users-me-Workspace-foo`).

That directory is **not** the full history. Claude Code hard-deletes transcripts once they pass `cleanupPeriodDays`, so the extractor also reads a backup mirror when one exists:

| Root | Default path | Override |
|------|--------------|----------|
| Live | `~/.claude/projects` | - |
| Backup mirror | `~/.claude-session-backups/projects` | `REFLECT_BACKUP_DIR` |

Sessions are unioned by session id with the live copy winning, so a mirror never double-counts. If `stats.txt` reports only one root, tell the user their history is capped at the retention window and point them at `examples/backup-sessions.sh` in this skill directory - an hourly rsync mirror is the fix, and it must never use `--delete`.

Decide what to mine from the user's request:

| User intent | Pass to the extractor |
|-------------|-----------------------|
| "all my sessions" / no project named | `all` |
| A specific repo, by path | the absolute path (it gets slugified) |
| A repo by name / partial name | the name as a substring (case-insensitive match) |

If the user is in a project and says "this one", use its working-directory path. List what's available with:

```bash
fd -H -t d -d 1 . ~/.claude/projects ~/.claude-session-backups/projects 2>/dev/null | xargs -n1 basename | sort -u
```

## Step 2 - Extract the corpus

Run the bundled extractor (it skips tool output, system reminders, slash-command wrappers, and subagent sidechains, keeping only the human's words; `[INTERRUPTED]` markers flag where the user stopped the agent mid-action - a strong friction signal):

The script ships next to this `SKILL.md`. Locate it rather than hardcoding a path - it lands somewhere different under a plugin install, a `~/.claude/skills` copy, and a `~/.agents/skills` symlink:

```bash
EXTRACT="$(fd -H -t f '^extract-corpus\.sh$' ~/.claude/plugins ~/.claude/skills ~/.agents/skills 2>/dev/null | head -1)"
bash "$EXTRACT" "<PROJECT or all>" ~/.claude/.cache/reflect
```

Requires `jq` and `awk` (the script preflights both and fails loudly with an install hint if either is missing). No other dependencies.

Read `~/.claude/.cache/reflect/stats.txt` and `manifest.json`. Check `roots=` (one root means a capped history - see Step 1) and `duplicate_sessions_skipped=`. The corpus is small (typically tens of KB even from a huge history), so it fits comfortably in a single agent's context - which means you fan out for **perspective**, not for size.

## Step 3 - Author and run a dynamic Workflow

Use the `Workflow` tool. Write the script fresh - below is a proven *shape*, not a script to copy verbatim. Vary the lenses and prompt wording each run.

1. **Mine (parallel, perspective-diverse).** Several agents each read the *whole* corpus (pass the chunk paths from the manifest) but hunt **one** lens apiece, so none gets distracted. Rotate/refresh the lenses between runs; a good spread:
   - version control & commit habits
   - verification discipline (claiming "done" without running it)
   - tool & shell choices
   - scope / over-building
   - communication & output style
   - context & process (re-explaining, repeated setup, ignored instructions)
   - a catch-all for anything the others miss
   Each finding must cite **2–4 verbatim quotes** copied from the corpus, plus the distinct sessions/projects it spans and its recency by session date.
2. **Cluster & rank (barrier).** One agent merges duplicates across lenses and ranks by impact (frequency × distinct-project spread × severity, recent weighted higher). Keep only **portable** patterns.
3. **Verify (parallel, one per top candidate).** Each agent greps the *real* `.jsonl` transcripts (`rg`/`jq` over `~/.claude/projects/<slug>/*.jsonl`) to confirm the pattern recurs in 2+ sessions, captures the assistant action that triggered the correction (the root cause, not the symptom), and **reads every instruction file discovered in Step 4** (the repo's `CLAUDE.md`/`AGENTS.md` set - root, `.claude/`, and per-directory - plus `~/.claude/CLAUDE.md` and any `CLAUDE.local.md`) to confirm it isn't already covered. Be adversarial: drop one-offs, noise, and already-covered items. Mining can hallucinate - never trust a pattern you have not grounded in a real quote.
4. **Synthesize.** One agent reads the current target files and produces (a) a ranked friction **report** with evidence and (b) **proposed edits**, each tagged with which file it belongs in (Step 4). Match each file's existing voice; do not duplicate rules already present; prefer fewer, sharper rules.

Constraints to bake into the prompts:
- **Portable & recurring only.** A pattern must appear across multiple sessions. Ignore anything tied to one bug, file, or API - but generalizable habits (commit style, verification, tool choice, tone) are in scope.
- **Evidence or it didn't happen.** Every proposed rule traces to verbatim user quotes.

## Step 4 - Route each improvement to the right file

**First discover where this repo actually keeps its instructions - never assume `CLAUDE.md`, or a single root file.** Two conventions exist (a repo may use either, both, or symlink them together): Claude-specific `CLAUDE.md` / `CLAUDE.local.md`, and the tool-agnostic `AGENTS.md` standard - each can sit at the repo root, under `.claude/`, and/or in any subdirectory (applies to that subtree, most-specific wins). Some repos shared with other agent tools standardise on `AGENTS.md` and have **no root `CLAUDE.md` at all**. List every instruction file before routing anything:

```bash
fd -H -i '^(claude|agents)(\.local)?\.md$' "<repo-root>"   # both conventions · root + .claude/ + nested
```

Read all of them (if `CLAUDE.md` and `AGENTS.md` are symlinked, they're one file - edit once). A rule is only "new" if it is absent from **every** one - checking a single file and declaring "nothing exists" is the blind spot that ships confidently-wrong duplicates.

Then route each finding to the **most specific existing file that owns its topic**; create a new file only when none fits:

| The finding is about… | Target |
|-----------------------|--------|
| How **the user** works across *all* repos (commit/tone/verification habits, tool prefs, planning) | `~/.claude/CLAUDE.md` - personal |
| A **repo-wide** convention any contributor needs (build/test, architecture) | the repo's established root instruction file - **whichever it already uses**: `AGENTS.md`, `<repo>/.claude/CLAUDE.md`, or `<repo>/CLAUDE.md`. Don't introduce a competing root file in the other convention |
| A convention specific to **one area** of the repo (a tool dir, tests, a service) | the instruction file (`CLAUDE.md` or `AGENTS.md`, matching the repo's convention) nearest that code; create one there if absent |
| Project-specific but **personal / not for teammates** | `<repo>/CLAUDE.local.md` (gitignored; copy a `.example` template if one exists) |

Heuristic: *Would every contributor want this?* → the repo's root/area file. *Would I want it in every repo?* → personal. *Just me, just here?* → `CLAUDE.local.md`. **Match the repo's established convention and layout** - route into its existing `AGENTS.md` or `.claude/`-plus-per-directory structure rather than imposing your own. Two caveats: a rule overriding a Claude harness default (e.g. an auto-added commit trailer) belongs in personal `CLAUDE.md`; and **Claude-specific behaviour never goes in `AGENTS.md`** - that file is shared with other agent tools, so keep it tool-agnostic and put Claude-only rules in `CLAUDE.md` / `CLAUDE.local.md`.

## Step 5 - Present and apply

Show the user a friction report plus the proposed edits **grouped by target file**, as a diff preview. **Do not auto-write.** Let the user approve per target (all / a subset / none). Then:

- Apply approved edits with surgical insertions that match each file's structure and voice.
- If creating a `CLAUDE.local.md`, ensure the repo's `.gitignore` excludes it (add it if missing) so personal notes never get committed.
- Never bump a project's version as a side effect, and never commit unless the user explicitly asks.

## Guardrails

- **Don't reprint last time.** If the user has run `reflect` before, lead with what's *new or still unaddressed*, not the same top-five.
- **Respect what's already there.** Discover and read *all* instruction files first (`fd -H -i '^(claude|agents)(\.local)?\.md$'` over the repo root, `.claude/`, and every subdirectory). Never declare "nothing exists" without checking `.claude/`, nested dirs, AND `AGENTS.md` - some repos standardise on `AGENTS.md` with no root `CLAUDE.md`. That omission is what produces confidently-wrong duplicates of rules the repo already states.
- **Shell:** `rg` not grep, `fd` not find, `bat` not cat; `jq` to parse transcripts.
- **The corpus is the user's words only** - it deliberately excludes the assistant's side and tool output, so judge friction from what the user had to say, and confirm the "why" against the full `.jsonl` only when grounding a finding.
