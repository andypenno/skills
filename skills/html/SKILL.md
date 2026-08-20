---
name: html
description: |-
  Trigger when conversation content needs to leave as one self-contained .html file - asked for "as a html doc/page", an html plan, report, spec or comparison, or with viewer intent ("view it on my phone", "put it in the MR"). Also on follow-ups naming an existing .html. Usually lowercase "a html"; don't wait for an output path.
  Keywords: html, html doc, html file, html page, html artifact, html plan, html report, self-contained, share this, view on my phone
---

# HTML - self-contained shareable documents

Turn content that already exists in the conversation into a **single, polished, self-contained `.html` file**. The HTML ask is a *presentation* step, not a cue to re-derive substance - format what's there, don't re-plan it.

The output's whole reason for existing: the user drops it in **Slack / a Jira comment / an MR description**, opens it **on their phone**, and anyone can read it **offline**. That makes self-containment the one inviolable rule.

## 0. The iron rule - self-contained, one file, zero network

Every emitted `.html` MUST open identically by double-click from `file://`, with no network. Build it so it survives being moved anywhere or pasted into a thread.

- **One inline `<style>`** in `<head>`. No `<link rel=stylesheet>`, no `@import`, no remote `url(...)`.
- **JS (now welcome) inline only** - classic `<script>`, never `<script src=...>`, never `type="module"` (ES modules die on `file://`).
- **Graphics = inline `<svg>` / pure CSS / `data:` URI** only. No remote `<img>`, no icon fonts.
- **Fonts = system stacks only** (`--sans` / `--mono` below). No web fonts, no `@font-face` fetch.
- **No relative asset paths** (`./img/…`, `../css/…`).
- ✅ Allowed: content hyperlinks (`<a href="https://…">` to a PR/Jira/ticket) - navigational, not a load-time dependency.

### Pre-delivery checklist (run before surfacing the file)
- [ ] Zero `<script src=`, `<link rel="stylesheet"`, `@import`, `type="module"`
- [ ] Zero `cdn.` / `googleapis` / `fonts.` / `src="http` / `url(http`
- [ ] All images are inline `<svg>` or `data:` URIs; no `@font-face`
- [ ] Exactly one `<style>` block; all JS inline
- [ ] Reads fine with JS disabled (progressive enhancement - nothing essential hidden behind JS)
- [ ] No `./` or `../` asset paths
- [ ] Opens from `file://` (clipboard/storage wrapped in try/catch)

Quick grep against the finished file:
```bash
rg -n 'src="http|rel="stylesheet"|@import|type="module"|@font-face|url\(http|cdn\.|googleapis' the-file.html
```
(No hits = clean. Content `<a href="https…">` links are fine and won't match.)

## 1. Build from the template

Start from **`template.html`** (in this skill dir) - copy it, don't hand-roll from scratch. It already carries the design system, the full component CSS, the mobile/print/reduced-motion blocks, and the baked-in JS (TOC scroll-spy, copy buttons, theme toggle, `<details>`). Then:

1. Set `<title>` and the `<h1>` + `.meta` provenance line.
2. Drop in the content using components from the menu (§4). Delete unused component CSS only if trimming for size - leaving it is harmless.
3. Keep the top 1–2 sections expanded; wrap long/secondary blocks (exhaustive tables, full dumps, appendices, Risks) in `<details>`.
4. Run the checklist, save (§6), surface the file (§6).

**`components.html`** is an openable gallery of every component rendered next to its markup - read it when you need the exact snippet, or send it to the user as a style reference.

## 2. Design system (GitHub-dark default)

Dark is the default landing theme (the user's established preference); a toggle swaps to light via the **same variable names**. Reference colours only via `var(--x)` - never hardcode hex in content.

| Token | Dark | Role |
|---|---|---|
| `--bg` | `#0d1117` | page background |
| `--panel` | `#161b22` | card / callout / `th` |
| `--border` | `#30363d` | rules, cell borders |
| `--text` | `#c9d1d9` | body text (softened - not pure white, avoids halation) |
| `--muted` | `#8b949e` | captions, meta |
| `--accent` | `#58a6ff` | links, h3, info/scope |
| `--green` / `--amber` / `--red` | `#3fb950` / `#d29922` / `#f85149` | now·done·ok / gated·warn / risk·bug |
| `--code-bg` | `#1f2630` | code background |
| `--mono` / `--sans` | system stacks | code / body |

Status is **colour + glyph/label**, never colour alone (colourblind + print): pair with ✅ ❌ or a tag word. The full token block (incl. the `[data-theme="light"]` variant and `--*-rgb` triplets for tag/callout fills) lives in `template.html`.

**"Do it in the style of `<path>`":** read that file first and mirror its CSS/structure - don't invent.

## 3. Structure spine

Default implementation-plan layout (adapt freely - the spine is a common case, not a law):

```
<h1>Subject</h1>
<p class="meta">Project · Area · Driver/ticket/PR</p>   ← provenance
<p class="legend">…tag vocabulary declared once…</p>
<h2>Context</h2>            one-paragraph framing + a summary callout
<h2>Scope</h2>              IN/OUT callout: ✅ in-scope, ❌ out-of-scope
<h2>Implementation</h2>     file-by-file: <p class="file">path</p> above each <pre>
<h2>Tests</h2>              table: Layer | File | Coverage
<h2>Verification</h2>       ordered steps
<h2>Risks</h2>              stacked .callout.risk / .callout.warn
<h2>Critical files</h2>     mono .file list
<footer>                    cross-ref the .md twin + how facts were verified
```

Variants: **design/scoping spec** (foreground a parameter table + error-model + limits + supported/unsupported), **diff/comparison** (`.cols` two-column + `.diff` spans + `.sw` legend; bump the `--wrap-max` token to 1080px), **numbered sections** (`<h2><span class="n">1</span>…` for refactor/init docs - skip Tests/Risks). Lead every section with its point; put any matrix in a table, not prose. Make each claim discrete and auditable.

## 4. Component menu

All defined in `template.html`; `components.html` mirrors those exact rules to render the gallery - change a component's CSS in **both** so the gallery keeps matching what ships.

| Component | Use for |
|---|---|
| `.callout` (`.warn`/`.risk`/`.ok`, opt. `.h`) | the few must-not-miss notes |
| `.tag` (`.now`/`.gated`/`.bug`/`.scope`…) | inline status pills |
| `.legend` + `.sw` | declare the tag/colour vocabulary once |
| `<table>` | any item × attribute matrix (never narrate it) |
| `<pre>`/`code` + `.file` | code (load-bearing only) + green-mono file paths |
| `<details>`/`<summary>` | collapse secondary detail (zero JS) |
| `.steps` | numbered procedure |
| `.flow` / `.node` / `.arrow` | pipeline / state diagram |
| `.grid2` + `.card.before/.after` | before/after comparison |
| `.tree` | annotated file tree (new/edit/dim) |
| `.cols`/`.col` + `.diff`/`.del`/`.add`/`.ctx` | side-by-side + unified diff |
| `.meta` / `.mono` / `.ok` / `.no` | inline helpers |

## 5. Interactivity (baked in) + charts (opt-in)

**Baked into `template.html`** - all vanilla, inline, `file://`-safe, degrading silently:
- **`<details>` collapsibles** - zero JS, the highest-value readability win.
- **Scroll-spy TOC** - auto-built from `h2`/`h3` (IDs auto-slugged), highlights the active section; sits in the left gutter on wide screens, becomes an inline box on narrow. Has the scroll-up fallback.
- **Copy-to-clipboard** on every `<pre>` - modern `navigator.clipboard` (works on `file://` - it's a secure context) with `execCommand` fallback.
- **Theme toggle** - `data-theme` swap, persisted to `localStorage` (try/catch - Firefox blocks it on `file://`; the toggle still works for the session). FOUC prevented by the blocking `<head>` init script.
- **Print-expand** - a `beforeprint` hook force-opens every `<details>` (collapsed ones don't render on print/PDF otherwise) and restores state after. So "print to PDF / share" never silently drops collapsed content.

**Opt-in (snippets in `components.html`, add when the data merits it):** stacked bar (CSS flex), donut/progress ring (SVG, `r=15.915`), sparkline (SVG polyline), progress bar. Theme them with `currentColor` + vars, give each an `aria-label`, gate motion behind `prefers-reduced-motion`. **Scroll-reveal animation** is available but lowest-priority - only if it earns its place, and always reduced-motion-gated.

Rule: graphics serve *parseability*, not flash. Never hide must-read content behind JS.

## 6. Delivery & lifecycle

1. **Save** to `~/.claude/plans/<slug>.html` (unless the user gives a path or it clearly belongs with project work). Slug = a short kebab descriptor of the subject.
2. **Surface it every (re)draft** - on the first draft **and** every update, do BOTH:
   - **Always print the `file://` link** to the saved path, on its own line, so the user can click/paste it straight into a browser. Format: `file:///Users/andrew/.claude/plans/<slug>.html` (absolute path, triple slash). This is non-negotiable - never report "done" without it.
   - If the harness exposes a file-sending tool (e.g. `SendUserFile`), also send the file for phone/Slack. If it doesn't - check, don't assume - the `file://` link is the delivery; never hallucinate the call.
   *"whenever you redraft the html, give me the download link."* / *"so I can open in the browser directly."*
3. **In-place updates** - on "update the html" / "we're missing a bunch", **re-read the existing file**, preserve its structure + CSS, apply deltas. Don't greenfield.
4. **Markdown twin** - if a companion `.md` already exists (or the user worked in markdown first), keep it in sync; never overwrite it. Don't force-create one for a fresh HTML-only ask. Reference it in the footer, never link it as a stylesheet/script.
5. **Mobile** - for any column-heavy doc (`.grid2`/`.cols`/`.flow`), the template's `@media (max-width:720px)` reflow is mandatory (collapses to one column) - phone viewing is a stated requirement.

## 7. Frictions to preempt

| Past correction | Preempt by |
|---|---|
| *"That html is boring"* | Lean **rich by default** - ship the full design system, callouts, tags, tables, a TOC. Plain output is a rejected failure mode. |
| *"Make it a **proper** html file"* / *"I'd prefer a html artifact"* | Always a complete, saved, self-contained `.html` file - never a chat-panel artifact or a fragment. |
| *"We're missing a bunch"* | Every claim discrete/auditable; tables for matrices; `<details>` so nothing is dropped for brevity. |
| *"Give me the download link… view it on my phone"* / *"so I can open in the browser directly"* | **Always print the `file://` link** after **every** generation (+ send the file if the harness has a file-sending tool). |
| *"Remove the code blocks in favour of file references"* | Reserve `<pre>` for load-bearing code; when a span just points at a known definition, use an inline `.file` reference. |
| Columns overflow on phone | The 720px reflow ships whenever side-by-side columns are used. |
