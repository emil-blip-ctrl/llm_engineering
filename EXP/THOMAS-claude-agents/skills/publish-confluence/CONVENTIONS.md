# /publish-confluence — Conventions

These conventions apply throughout the `/publish-confluence` workflow. Load on demand; the
[SKILL.md](SKILL.md) steps reference them.

- **One Confluence page per source section/document.** Mirror the source hierarchy as a
  parent → child page tree (e.g. an "All Agents" landing page with one child per agent).
- **Emoji at the front of section/landing titles** for scannability. Default mapping:

  | Section | Emoji | | Section | Emoji |
  |---------|-------|-|---------|-------|
  | Overview / home | 📖 | | Teams | 🧩 |
  | Data Model / schema | 🗺️ | | Agents | 🤖 |
  | Context & Memory | 🧠 | | Skills | ⚡ |
  | Versioning / Distribution | 📦 | | Operations / runbook | 🛠️ |

  Choose a fitting emoji for anything unlisted; keep exactly one, at the front of the title.
- **Root title carries the plugin version; each object page title carries its own object version.**
  The plugin is the one installable/pinnable unit, so suffix the **root/landing page** with the plugin
  (bundle) version from `.claude-plugin/plugin.json` `version`, e.g. `📦 Agentic-Claude — Library (v1.2)`.
  Each agent/skill/team also carries an informational semver in its own frontmatter (`version:`); suffix
  **its detail page title** with that object version, e.g. `🤖 Developer (v1.1)`, `⚡ /develop (v1.1)`,
  `🧩 Feature Team (v1.1)`. Read object versions from each object's frontmatter and the plugin version from
  `plugin.json` (fall back to the latest git tag); never hand-type either into titles. A title only churns
  when that object's own version actually changes.
- **Titles are plain text — never HTML-escape them.** Use a literal `&`, `<`, `>` in a title
  (`🤖 All Agents & Relations`), never the entity (`&amp;`). Escaping applies only to ADF *body* content.
- **Diagrams → Mermaid first.** A source `<svg>` cannot live in ADF, so convert each diagram
  (entity maps, flows, layer stacks) to **Mermaid**: validate the syntax with the Mermaid Chart tool,
  then embed the Mermaid source as a fenced code block (`<pre><code class="language-mermaid">…</code></pre>`).
  It renders as a diagram where the Confluence Mermaid app is installed and degrades to readable source
  where it isn't — so also include a link to the interactive **Mermaid Live** URL (returned by the render
  tool) as a fallback. Escape `<`/`>` inside the code block (`&lt;br/&gt;`). If a richer always-rendered
  picture is required and the Mermaid app is unavailable, create the diagram in **Lucid** and embed the
  share link. **Never paste raw `<svg>`** — ADF drops it.
- **Read-only + version banner on every page.** After publishing, restrict editing to the publishing
  account and prepend one info panel to every page body with a do-not-edit notice. On an **object page**
  the banner shows BOTH the object version (from frontmatter) and the plugin version it ships in, e.g.
  *"Developer v1.1 · ships in Agentic-Claude v1.2 — auto-generated from git, do not edit here."* On the
  **root page** show just the plugin version, e.g. *"Auto-generated from git (Agentic-Claude v1.2) — do not
  edit here."* Object versions are read from each object's frontmatter and the plugin version from
  `plugin.json`, never authored per page. Re-running replaces the existing banner in place (idempotent)
  rather than stacking a second one.
- **Cross-link related objects.** Every **agent** detail page ends with a *Related skills* section that
  links (as real page links) to the skill pages that agent runs, plus its team membership and the
  *All Agents* landing page — e.g. Developer → `/develop`, `/review`; DevOps → `/deploy`; the PO links the
  skills it orchestrates. Each **skill** page notes its natural agent; landing pages link to every detail
  page beneath them. Links resolve only once targets exist, so create all pages first, then wire links.
- **Idempotent.** Re-running updates pages in place (matched by title) and bumps the version.
