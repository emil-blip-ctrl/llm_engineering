# Agentic-Claude — Versioning & Distribution

How the library is versioned, packaged as a Claude Code plugin, and consumed by projects.

Current version: **v1.2**

---

## Release History

| Version | Date | Highlights |
|---------|------|-----------|
| **v1.2** | 2026-06-03 | Model upgrades (opus-4-8), `setup.ps1` bootstrap, `update.ps1` auto-updater, Architect added to Full Team, plugin how-to guide |
| v1.1 | 2025 Q4 | Memory architecture (project scope), `team-findings.md`, session handoffs, crash-recovery checkpoints, team compositions |
| v1.0 | 2025 Q3 | Initial release: 6 agents, 6 skills, installer, workspace template, plugin manifest |

```powershell
# List all tagged versions
git tag -l -n1
```

---

## Two Consumption Modes

| Mode | How | Best for |
|------|-----|----------|
| **Track latest** | User-level junctions: `~/.claude/agents/` → this repo's `agents/` | Personal dev — new agents/skills appear automatically on `git pull` |
| **Pinned** | Plugin at project scope pinned to a git tag (e.g. `v1.2`) | Team / reproducible builds — frozen until pin is explicitly bumped |

Different projects can pin different versions simultaneously — project-scope settings
override user-scope settings in Claude Code.

---

## Plugin Packaging

Agents + skills + teams ship as **one versioned unit**. There is no per-agent versioning —
the whole library is the unit of release.

| File | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin manifest — `name: agentic-claude`, semver version, auto-discovers `agents/` and `skills/` |
| `.claude-plugin/marketplace.json` | Marketplace catalog — GitHub source + pinned git tag |

### Installing the plugin

```text
# Add the marketplace (reads marketplace.json from the repo default branch)
/plugin marketplace add Aletheia-Thomas/Claude-Agents

# Install the plugin — pinned to the version in the marketplace entry
/plugin install agentic-claude@agentic-claude-lib
```

### Pinning a project to a specific version

Add to the project's `.claude/settings.json` (project scope overrides user scope):

```jsonc
{
  "extraKnownMarketplaces": {
    "agentic-claude-lib": {
      "source": { "source": "github", "repo": "Aletheia-Thomas/Claude-Agents" }
    }
  },
  "enabledPlugins": [ "agentic-claude@agentic-claude-lib" ]
}
```

---

## Keeping Models Up to Date

Run `templates/update.ps1` to detect and apply model upgrades across all AGENT.md files:

| Command | Effect |
|---------|--------|
| `.\templates\update.ps1` | Dry-run — shows outdated model IDs, no changes written |
| `.\templates\update.ps1 -Apply` | Writes updated model IDs to all AGENT.md files |
| `.\templates\update.ps1 -Apply -BumpVersion` | Also bumps version in `plugin.json` / `marketplace.json` |
| `.\templates\update.ps1 -Apply -ProjectPath "C:\path\to\project"` | Updates copy-mode agents in a consuming project |

---

## Releasing a New Version

1. Update agent AGENT.md files if needed (`update.ps1 -Apply`)
2. Update `CHANGELOG.md` with the new version entry
3. Bump version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
   (`update.ps1 -Apply -BumpVersion` does steps 1–3 together)
4. Commit and push
5. Tag the release: `git tag v1.X && git push --tags`

> **Tag naming:** prefer full semver tags (`v1.2.0`) so the git tag and `plugin.json`
> version field line up exactly.

---

## GitLab Migration

When the repo moves to `git-scm.tcsgroup.ch`, update the marketplace `source` in
`.claude-plugin/marketplace.json`:

```jsonc
// Before (GitHub):
"source": { "source": "github", "repo": "Aletheia-Thomas/Claude-Agents" }

// After (GitLab / self-hosted):
"source": { "source": "url", "url": "https://git-scm.tcsgroup.ch/<group>/claude-agents.git", "ref": "v1.2.0" }
```

Everything else (plugin.json, consuming project settings.json) stays the same.
