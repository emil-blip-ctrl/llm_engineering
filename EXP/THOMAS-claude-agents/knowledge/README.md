# Technology Knowledge Base — Architecture

**Status:** Foundation (Phase 1 — skeleton). **No technology content authored yet.**
**Owner:** repo-improvement-team (librarian). **Last-reviewed:** 2026-06-11.

---

## Purpose

This is the **central, hierarchical technology knowledge base (KB)** for the Agentic-Claude library. It holds the *technology-specific* knowledge that the platform stack (~300 technologies across the TCS taxonomy) requires — facts, conventions, common tasks, and gotchas for each technology — in one place, organized by platform.

It exists so that:

- **Skills stay technology-AGNOSTIC.** A skill describes a *workflow* (explore → plan → implement → report). It must not hard-code IDIT, SAP, or M365 specifics. Technology depth lives here, not in `skills/`.
- **Agents stay roles, not projects.** A role agent (developer, architect, tester…) *references* the relevant pack when it works on that technology, rather than carrying the knowledge in its definition.
- **Knowledge is written once and referenced many times.** A single pack per technology is read by every agent and skill that touches it.

## The central-KB model (and why central at 300-technology scale)

Two rejected alternatives, and why this model wins as the catalog approaches ~300 technologies:

| Model | What it means | Why rejected / chosen |
|-------|---------------|------------------------|
| **Per-skill bundling** | Each skill ships its own copy of the technology facts it needs | Rejected — duplication explodes. The same IDIT or APIC facts would live in `/develop`, `/test`, `/review`, `/deploy`… N skills × M technologies copies to keep in sync. Unmaintainable at 300 technologies. |
| **Per-technology agents** | One agent per technology (an "IDIT agent", an "SAP agent"…) | Rejected — ~300 agents is sprawl, breaks "agents are roles not projects," and multiplies the inventory/commit-guard surface. |
| **Central hierarchical KB** (this) | One pack per technology, in a shared tree, referenced by agnostic skills and role agents | **CHOSEN.** Write-once / reference-many. Skills and agents stay lean and reusable; depth scales horizontally by adding files, not agents or skill copies. |

This is the research-backed ecosystem **Pattern B+C**: agnostic skills (B) over a referenced central knowledge layer (C).

## Folder schema

```
knowledge/
  README.md          # this file — KB architecture
  _TEMPLATE.md       # the standard technology-pack template (authors copy this)
  <group>/
    <platform>/
      README.md       # platform index — name, parent group, seed technology list
      <technology>.md  # one pack per technology (created on first use — none exist yet)
```

- **Group** — one of the four taxonomy groups: `customer-journey`, `business-capability`, `data-capability`, `core-it`.
- **Platform** — a platform within a group (e.g. `idit`, `collaboration`, `big-data`).
- **Technology pack** — a single `<technology>.md` per technology, built from `_TEMPLATE.md`. **None are authored at this stage.**

## Naming & slug rules

- Folders and pack filenames use **lowercase-kebab-case** slugs: `internal-developer-platform`, `business-intelligence`, `sf-mce-mcp`.
- A pack filename is the technology slug plus `.md`: `m365.md`, `confluence.md`.
- Brand/product names keep their natural spelling in frontmatter `name:` and headings (e.g. `M365`, `TCS.CH`); only the slug is normalized.
- One technology = one pack. Do not split a technology across files or merge two technologies into one.

## How agents & skills reference a pack

Reference packs by **relative link**, never by copying content:

- From an **agent** (`agents/<agent>/AGENT.md`):
  `../../knowledge/<group>/<platform>/<technology>.md`
- From a **skill** (`skills/<skill>/SKILL.md`):
  `../../knowledge/<group>/<platform>/<technology>.md`

Convention: a skill stays agnostic and says *"if working with technology X, load its pack from `knowledge/…`"*; it never inlines the pack. An agent links the packs relevant to its current task. This keeps the knowledge single-sourced and the linker free to load on demand (progressive disclosure).

## Scale-governance approach

At ~300 packs, the CLAUDE.md **Self-Maintaining Inventory** must **NOT** enumerate technology packs — that would be unmaintainable and would defeat the point of a central KB. The inventory continues to track only agents, skills, and teams.

Instead, the KB is governed by:

1. **A generated KB index** (planned) — a script walks `knowledge/<group>/<platform>/` and emits an index of packs with their `status`, `owner`, and `last-reviewed`. The index is generated, never hand-maintained.
2. **A template-conformance lint** (planned — NOT implemented now) — a future **extension to the commit-guard**, owned by the **library-engineer**, that checks each `<technology>.md` carries the required frontmatter (`name`, `platform`, `group`, `owner`, `last-reviewed`, `status`) and the mandated section headings from `_TEMPLATE.md`. This is the depth standard, machine-checked. It is **deferred** — the current commit-guard still checks only agent/skill/team counts + AGENT/SKILL frontmatter, and is untouched by this foundation.

The CLAUDE.md Repository Structure tree references `knowledge/` as a **single entry** describing the taxonomy KB — it does not list platforms or packs.

## Lifecycle & light versioning

Each pack carries lightweight lifecycle metadata in its frontmatter — **not** full semver (packs are knowledge, not installable objects):

- **`owner`** — the person/role accountable for the pack's accuracy.
- **`last-reviewed`** — the date the content was last verified (ISO `YYYY-MM-DD`). Stale packs are surfaced by the generated index.
- **`status`** — `stub` (placeholder, no real content) → `draft` (authored, unreviewed) → `reviewed` (verified accurate).

Packs move through `stub → draft → reviewed`. There is no per-pack semver and no `VERSIONS.md`; the frontmatter is the single source of truth and the generated index is the rollup.

## What this foundation is (and is not)

- **Is:** the architecture (this file), the pack template (`_TEMPLATE.md`), and an empty group/platform folder skeleton with platform `README.md` indexes.
- **Is not:** any authored technology pack, any platform team, or any commit. Those come in later phases (see `docs/library-expansion-proposal.md`).
