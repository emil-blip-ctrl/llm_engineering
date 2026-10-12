---
name: per-object-versioning
description: Decision to add informational per-object semver (agents/skills/teams) on top of the single plugin semver, and the resulting reversal of the Confluence title convention
metadata:
  type: project
---

APPLIED 2026-06-03 in plugin release 1.2.0 (the human still needs to create git tag v1.2.0). The library has independent, INFORMATIONAL semver on every agent (6), skill (7), and team (3) via frontmatter `version:`, on top of the single authoritative plugin semver in `.claude-plugin/plugin.json`. Claude Code acts ONLY on the plugin version; object versions exist purely so humans can see what changed.

Starting versions: developer/tester/devops/documentarian/product-owner-assistant=1.1.0, architect/librarian/library-engineer=1.0.0; skills develop/test/deploy/review/document=1.1.0, postman-collection-generator/publish-confluence=1.0.0; teams feature/release/full=1.1.0, repo-improvement=1.0.0.

**Why:** humans wanted per-object change visibility surfaced in Confluence titles/banners; plugin remains the only installable/pinnable unit.

**How to apply:**
- This DELIBERATELY REVERSES the long-standing publish-confluence rule "version on root only, child titles clean" (was at SKILL.md ~L33-40). New rule: root title = PLUGIN version; child titles = OBJECT version from frontmatter; banner shows both (`Developer v1.1 · ships in Agentic-Claude v1.2`). Do NOT "restore" the old clean-child-title convention — it was intentionally dropped.
- Teams (teams/*.md) had NO frontmatter; recommendation is to add minimal YAML (`name:`, `version:`) so the commit-guard can lint them and the publish skill has one parse path.
- VERSIONS.md manifest was REJECTED as redundant: frontmatter is the single source of truth, surfaced via Confluence/presentation.
