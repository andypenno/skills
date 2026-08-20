---
name: notes
description: |-
  Trigger when something should go into, or come out of, the user's Obsidian vault - explicit vault talk, or casual capture and recall ("write that down", "log this", "what do I have on X"). Also before searching code or the web on a task naming a project, service, team or technology. Not for repo docs, READMEs or CLAUDE.md.
  Keywords: notes, vault, Obsidian, knowledge base, daily log, meeting notes, write that down, log this, search my vault, what do I have on
---

# Notes - Obsidian Knowledge Base Manager

Manage the user's Obsidian vault using the `mcp__obsidian__*` MCP tools. The vault is the user's personal knowledge base - treat it as a living system of interconnected notes, not just a folder of files.

## Prerequisites - first-time setup

Before using this skill, the MCP tools it depends on must be available. If `mcp__obsidian__*` tools are not present in your tool list, the vault isn't connected yet. Walk the user through setup:

### 1. Install Obsidian

```bash
# macOS (Homebrew)
brew install --cask obsidian

# Or download from https://obsidian.md for any platform
```

### 2. Install Node.js (v18+)

The MCP server runs via `npx`, which requires Node.js. Check with `node --version`. If missing, install via your preferred method (fnm, nvm, Homebrew, or direct download from https://nodejs.org).

### 3. Create the vault

Choose a folder for the vault (e.g. `~/Knowledge`, `~/Notes`, `~/Vault` - any path works). Create the folder structure:

```bash
mkdir -p ~/Knowledge/{Projects,People,References,Meeting-Notes,Daily,Templates}
```

Then open Obsidian, click "Open folder as vault", and select that folder.

### 4. Create templates

Write the following template files into the `Templates/` folder. These provide consistent structure for different note types.

**Templates/Project.md:**
```markdown
---
type: project
status: active
tags: []
created: {{date}}
---

## Goal

## Key Decisions

## Open Questions

## Action Items

## Links
```

**Templates/Meeting-Note.md:**
```markdown
---
type: meeting
attendees: []
date: {{date}}
project: 
tags: []
---

## Agenda

## Notes

## Action Items

- [ ] 
```

**Templates/Person.md:**
```markdown
---
type: person
role: 
organisation: 
tags: []
---

## About

## Notes

## Interactions
```

**Templates/Reference.md:**
```markdown
---
type: reference
source: 
tags: []
created: {{date}}
---

## Summary

## Key Points

## Quotes

## Related
```

**Templates/Daily.md:**
```markdown
---
type: daily
date: {{date}}
tags: []
---

## Today's Focus

## Log

## Tomorrow
```

### 5. Connect the MCP server

Add the MCPVault server to Claude's configuration. The path must point to the vault folder you created.

**For Claude Code** - add to `~/.claude.json` under the `mcpServers` key:

```json
"obsidian": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@bitbonsai/mcpvault@latest", "/absolute/path/to/your/vault"],
  "env": {}
}
```

**For Claude Desktop** - add to the `mcpServers` section in:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%/Claude/claude_desktop_config.json`

```json
"obsidian": {
  "command": "npx",
  "args": ["@bitbonsai/mcpvault@latest", "/absolute/path/to/your/vault"]
}
```

Then restart the Claude client. The `mcp__obsidian__*` tools should appear.

### 6. (Optional) Version control

Initialize a git repo in the vault folder for history and backup:

```bash
cd /path/to/vault
git init
echo '.obsidian/workspace.json\n.obsidian/workspace-mobile.json\n.obsidian/cache\n.trash/' > .gitignore
git add -A && git commit -m "Initial vault setup"
```

---

## Discovering the vault

The vault path is configured in the MCP server, so you don't need to know it in advance. Use `mcp__obsidian__list_directory` with path `/` to see the top-level structure. If the vault is freshly created and follows the setup above, you'll see the standard folders. If it's an existing vault with a different structure, adapt - read what's there and work with the user's existing organisation.

## Vault structure (default)

The setup above creates this layout. Existing vaults may differ - always check with `mcp__obsidian__list_directory` first.

```
Projects/        ← one note per active project
People/          ← contacts, colleagues, stakeholders
References/      ← articles, books, tools, resources
Meeting-Notes/   ← dated meeting notes
Daily/           ← daily journal entries
Templates/       ← note templates (don't modify these)
```

## Creating notes

When the user wants to create a note, pick the right template based on the type of information:

| Type | Folder | Template | Naming convention |
|------|--------|----------|-------------------|
| Project | `Projects/` | `Templates/Project.md` | `Projects/Project Name.md` |
| Meeting | `Meeting-Notes/` | `Templates/Meeting-Note.md` | `Meeting-Notes/YYYY-MM-DD Topic.md` |
| Person | `People/` | `Templates/Person.md` | `People/Full Name.md` |
| Reference | `References/` | `Templates/Reference.md` | `References/Title.md` |
| Daily | `Daily/` | `Templates/Daily.md` | `Daily/YYYY-MM-DD.md` |

### How to create a note

1. Read the matching template with `mcp__obsidian__read_note`
2. Replace `{{date}}` placeholders with today's date (YYYY-MM-DD)
3. Fill in the frontmatter fields from what the user told you (e.g. attendees, project, tags)
4. Add any content the user provided into the appropriate sections
5. Write the note with `mcp__obsidian__write_note`

Always populate the frontmatter - it's what makes notes searchable and filterable. If the user doesn't specify tags, infer reasonable ones from the content.

If the vault doesn't have a `Templates/` folder or uses different templates, adapt. Read whatever templates exist and follow the user's conventions.

## Searching and finding notes

Use `mcp__obsidian__search_notes` to find notes by content or frontmatter. Common searches:

- **By topic**: search for keywords in content
- **By type**: search frontmatter for `type: project`, `type: meeting`, etc.
- **By status**: search frontmatter for `status: active`, `status: completed`
- **By tag**: use `mcp__obsidian__list_all_tags` to see what tags exist, then search for specific ones
- **By person**: search for names in content or attendees fields

When presenting search results, give a concise summary - note title, type, and a relevant snippet. Don't dump raw content.

## Linking notes together

Obsidian uses `[[wiki-links]]` to connect notes. When creating or editing notes, actively look for opportunities to link:

- Mention a person? Link to `[[Full Name]]` if they have a People note
- Mention a project? Link to `[[Project Name]]`
- Reference a meeting? Link to `[[YYYY-MM-DD Topic]]`

Use `mcp__obsidian__search_notes` to check if a related note exists before linking. If it doesn't exist and should, offer to create it.

## Updating notes

- **Status changes**: Use `mcp__obsidian__update_frontmatter` to change `status: active` to `status: completed` (or `on-hold`, `archived`)
- **Adding tags**: Use `mcp__obsidian__manage_tags` with operation `add`
- **Appending content**: Use `mcp__obsidian__write_note` with `mode: append` to add to an existing note without overwriting it
- **Editing sections**: Use `mcp__obsidian__patch_note` for targeted edits within a note

## Reviewing action items

Action items live in Meeting Notes and Project notes as Markdown checkboxes (`- [ ]`). To find open action items:

1. Search for `- [ ]` across the vault using `mcp__obsidian__search_notes`
2. Group results by project or meeting
3. Present them as a clear checklist with context (which note they're from, when they were created)

## Vault overview

When the user asks for an overview or summary:

1. Use `mcp__obsidian__get_vault_stats` for high-level stats
2. Use `mcp__obsidian__list_directory` on key folders to show what's there
3. Use `mcp__obsidian__list_all_tags` to show the tag landscape
4. Summarise: how many projects (active vs completed), recent meetings, frequently used tags

## General principles

- **Be concise in responses** - the user can open Obsidian to browse. Give them just enough to act on.
- **Preserve existing content** - when updating notes, use `append` or `patch_note` rather than overwriting unless the user explicitly asks for a rewrite.
- **Maintain consistency** - follow the existing naming conventions and frontmatter patterns. If the vault already uses certain tags, prefer those over inventing new ones.
- **Link liberally** - the value of a knowledge base grows with connections between notes. Always look for linking opportunities.
- **Date everything** - meetings, daily notes, and action items should always have dates. Use ISO format (YYYY-MM-DD).
- **Adapt to the vault** - not every vault will follow the default structure. Discover what exists before assuming.
