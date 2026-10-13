---
name: publish-confluence
version: 1.1.1
type: technological
category: documentation-platform
platform: Confluence (Atlassian Cloud) · ADF
standards:
  - Atlassian Document Format (ADF) specification
  - Confluence REST API v2
description: >
  Publish a repository's documentation or presentation to Confluence as a navigable,
  read-only page tree using native ADF (via the Atlassian MCP). Mirrors the source structure
  as subpages, puts emoji in section titles, stamps the bundle version on the root title plus a
  generated banner on every page, renders diagrams as Mermaid (or Lucid embeds), wires cross-links,
  and is idempotent.
  Use when the user says "publish to Confluence", "update the wiki", or "publish the docs/presentation".
allowed-tools: Read, Grep, Glob, Task, mcp__claude_ai_Atlassian__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian__getConfluenceSpaces, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__createConfluencePage, mcp__claude_ai_Atlassian__updateConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Mermaid_Chart__validate_and_render_mermaid_diagram, mcp__claude_ai_Lucid__lucid_create_diagram_from_specification, mcp__claude_ai_Lucid__lucid_create_document_share_link
---

# /publish-confluence — Publish a doc tree to Confluence

Publishes a source (a presentation HTML, a `docs/` tree, or the library's agents/skills/teams)
into Confluence as a **read-only, navigable page tree** that stays in sync with the repo.
Output is **native Confluence (ADF)** — searchable and commentable — not a screenshot.

## Conventions (apply throughout)

The publishing conventions — page-tree shape, emoji titles, plugin/object version stamping,
plain-text titles, Mermaid/Lucid diagram handling, read-only version banners, cross-linking, and
idempotency — are detailed in **[CONVENTIONS.md](CONVENTIONS.md)**. Read that file before publishing
and apply every rule it lists throughout the steps below.

## Step 1 — Identify source and target

1. Read the source to publish. Note its sections and any diagrams.
2. Resolve the Confluence target: space + root/parent page. If only a page URL is given, fetch it
   with `getConfluencePage`. Get the numeric `spaceId` via `getConfluenceSpaces` (creation needs the
   Long id, **not** the space key).
3. Read the object version(s) from the source (plugin.json, tag, frontmatter).

## Step 2 — Plan the page tree

Produce a parent/child outline: landing pages ("All X") with detail pages beneath. Decide which
pages need diagrams. Confirm the outline with the user if it isn't obvious from the source.

## Step 3 — Convert each section to ADF (the MCP's HTML dialect)

- headings / paragraphs / lists / tables → kept as-is
- callouts → panels: `<div data-type="panel-info|note|success|warning|error">`
- key/value chips (model, tools, status) → `<span data-type="status" data-color="...">`
- multi-column blocks → `<section data-type="layout-two-equal|layout-three-equal">`
- strip presentational `class` / `style` / `onclick` (ADF ignores them)
- remember: **no inline SVG, no arbitrary iframe** in ADF — those become diagrams (Step 4)

## Step 4 — Render diagrams

For each needed diagram:
1. Author Mermaid source; validate it with the Mermaid Chart tool.
2. Embed via the Confluence Mermaid macro. If unavailable, create it in Lucid and embed the share link.
3. If neither is possible, add a note linking to the interactive source — never a broken/empty block.

## Step 5 — Create / update pages

1. Create parents/landings first to obtain their IDs; then children (`parentId`).
2. Title each page per the **emoji** conventions (plugin version on the root title; each object's own version, from its frontmatter, on its detail page title).
3. Re-run = find the page by title (`getConfluencePage` / `searchConfluenceUsingCql`), then
   `updateConfluencePage` with `includeBody:false` and a version-bump message.

## Step 6 — Wire links

- Parent⇄child navigation is automatic (Confluence page tree + breadcrumbs).
- Make landing pages link to their detail pages, and add the source's cross-relations as page links.
  Links resolve only once the target exists — create all pages first, then add links
  (`<a href=".../pages/<id>">` is converted to a proper page link by the MCP).

## Step 7 — Lock & report

1. Apply read-only restrictions (editing limited to the publishing account).
2. Report: the page tree (titles + URLs), diagrams rendered (Mermaid/Lucid), and anything that
   needs a human (e.g. "Mermaid macro not installed — used a Lucid embed instead").
