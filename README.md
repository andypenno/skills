# skills

Personal agent skills, published as a Claude Code plugin marketplace and consumable by Codex and opencode from the same tree.

## Install

### Claude Code

```
/plugin marketplace add andypenno/skills
/plugin install skills@andypenno
```

Or declare it in `~/.claude/settings.json` so it installs and updates without any interactive step:

```json
{
  "extraKnownMarketplaces": {
    "andypenno": {
      "source": { "source": "github", "repo": "andypenno/skills" }
    }
  },
  "enabledPlugins": {
    "skills@andypenno": true
  }
}
```

Skills are namespaced by the plugin: `/skills:qa-loop`.

### Codex · opencode

Both read the open agent-skills path, so clone once and symlink the skills in:

```sh
git clone https://github.com/andypenno/skills.git ~/.cache/andypenno-skills
mkdir -p ~/.agents/skills
for d in ~/.cache/andypenno-skills/skills/*/; do
  ln -sfn "$d" ~/.agents/skills/"$(basename "$d")"
done
```

Update with `git -C ~/.cache/andypenno-skills pull`. Restart the harness to re-discover.

## Skills

Grouped by domain. Every skill is discoverable and user-invocable; the pattern column says who normally fires it.

### Engineering

| Skill | Fires when | Pattern |
|---|---|---|
| `code-review` | A review is asked for without a named lens. The shared scope/context/reporting contract the lenses reuse. | auto |
| `review-correctness` | The question is whether the change is *right* - bugs, edge cases, blast radius. | auto |
| `review-simplicity` | The question is whether the code should exist - over-engineering, duplication, dead flexibility. | auto |
| `review-tests` | The question is the test suite - coverage of the change, false confidence, flakiness. | auto |
| `qa-loop` | Independent subagent reviewers, round-based until every lens returns PASS. | user only |
| `changelog` | What changed between two points in git history needs writing up. | auto |
| `hooks` | Authoring or debugging a verification hook - git pre-commit/pre-push, or a Claude Stop hook. | auto |
| `secret-hygiene` | A credential may be in the tree, the history, or a log; or a repo is about to go public. | auto |

### Operations

| Skill | Fires when | Pattern |
|---|---|---|
| `triage` | Something that worked has broken and the question is when and why. | auto |
| `measure` | Before any benchmark, profile or leak hunt, and for any before/after comparison. | auto |
| `watch-mr` | An open PR/MR needs following over time until it is mergeable. Owns the merge-readiness gate. | user only |
| `mr-comments` | Review feedback needs reading or acting on; unresolved threads. | auto |
| `watch-ci` | CI on a PR or MR needs following to a conclusion. GitHub and GitLab, incl. self-hosted. | user only |

### Authoring

| Skill | Fires when | Pattern |
|---|---|---|
| `agent-authoring` | Writing or editing text an agent reads - `SKILL.md`, `CLAUDE.md`, `AGENTS.md`, tool descriptions, subagent prompts. | auto |
| `docs-audit` | Docs need checking rather than writing - stale claims, or written for the wrong reader. | user only |
| `html` | Conversation content needs to leave as one self-contained shareable `.html` file. | auto |

### Handover

| Skill | Fires when | Pattern |
|---|---|---|
| `handoff` | Your own work continues in another session or by another agent. | user only |
| `agent-brief` | An agent owning a different system needs a contract block carried to it. | auto |

### Personal

| Skill | Fires when | Pattern |
|---|---|---|
| `notes` | Something should be written into, or looked up from, the Obsidian vault. | auto |
| `reflect` | Learning from past sessions - recurring friction, evidence-backed instruction-file edits. | auto |

## Layout

```
.claude-plugin/
├── marketplace.json    # marketplace: andypenno
└── plugin.json         # plugin: skills — the plugin root IS the repo root
skills/<name>/SKILL.md  # flat, one directory per skill
docs/AUTHORING.md       # conventions for adding a skill
```

The plugin root is the repo root, so top-level `skills/` is both Claude Code's default scan path and the flat layout other tooling expects — no `skills` field in `plugin.json`, and therefore no minimum Claude Code version. Skills sit flat: declared subdirectories are not scanned recursively, so domain grouping stays in this README as a reading aid, not a path.

## Adding a skill

Read [`docs/AUTHORING.md`](docs/AUTHORING.md), then validate before pushing:

```sh
claude plugin validate .
```

## License

MIT
