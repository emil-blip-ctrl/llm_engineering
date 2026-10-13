# Plugin Setup — How to Install Agentic-Claude

This guide covers three installation paths, from the fastest (plugin native) to the most flexible (manual symlinks). All three end up in the same state: agents and skills available in your project, workspace configured, CLAUDE.md ready.

---

## Path 1 — Plugin native (recommended for pinned versions)

The Claude Code plugin system lets you pin a specific library version and manage updates explicitly. This is the best option for team projects where everyone should run the same version.

### 1. Register the marketplace (once per machine)

```text
/plugin marketplace add Aletheia-Thomas/Claude-Agents
```

This reads `marketplace.json` from the library's default branch and registers `agentic-claude-lib` as a known source.

### 2. Install the plugin

```text
/plugin install agentic-claude@agentic-claude-lib
```

Claude Code pulls the version pinned in `marketplace.json` (currently `v1.2`) and makes all agents and skills available in the current scope.

### 3. Pin to a specific version in a project

To lock a project to a specific version (so teammates all run the same agents), add this to the project's `.claude/settings.json`:

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

Different projects can pin different versions simultaneously — project scope overrides user scope.

### 4. Set up the workspace

Even with the plugin installed, you need a multi-root VS Code workspace so Claude can see the team compositions. Copy the template:

```powershell
Copy-Item "C:\path\to\Claude-Agents\templates\project.code-workspace" `
          "C:\path\to\MyProject\MyProject.code-workspace"
```

Then edit the `path` values and open via **File → Open Workspace from File**.

---

## Path 2 — One-shot bootstrap (recommended for new projects)

The `setup.ps1` script installs everything in one command — agents, skills, workspace, hooks, CLAUDE.md template, `.gitignore`, and memory scaffold.

```powershell
# From the Claude Agents library root:
powershell -ExecutionPolicy Bypass -File templates/setup.ps1
```

The script is interactive by default (asks for project path, detects project type). For CI or silent installs:

```powershell
powershell -ExecutionPolicy Bypass -File templates/setup.ps1 `
  -ProjectPath "C:\path\to\project" `
  -Silent
```

| Flag | Default | Description |
|------|---------|-------------|
| `-ProjectPath` | current dir | Target project |
| `-ProjectName` | dir name | Used in workspace file and CLAUDE.md |
| `-Mode` | `symlink` | `symlink` = follows HEAD; `copy` = static snapshot |
| `-PinVersion` | — | Git tag to checkout when Mode=copy (e.g. `v1.2`) |
| `-Silent` | off | Skip all interactive prompts |

After running, open `<ProjectName>.code-workspace` in VS Code and run `claude` from the integrated terminal.

---

## Path 3 — Manual (Unix/Mac or custom Windows setups)

```bash
# From your project root:
mkdir -p .claude/agents .claude/skills

# Symlink all agents
for agent in developer tester devops documentarian product-owner-assistant architect; do
  ln -s /path/to/Claude-Agents/agents/$agent .claude/agents/$agent
done

# Symlink all skills
for skill in develop test deploy review document postman-collection-generator; do
  ln -s /path/to/Claude-Agents/skills/$skill .claude/skills/$skill
done

# Copy hooks template
cp /path/to/Claude-Agents/templates/settings.json .claude/settings.json

# Copy CLAUDE.md template
cp /path/to/Claude-Agents/templates/project-claude.md CLAUDE.md
```

---

## Keeping agents up to date

### Symlink mode (auto)

Symlinks always point to the library's current working tree. Pull the library and every project using symlinks gets the update instantly:

```powershell
cd "C:\path\to\Claude-Agents"
git pull
```

### Copy mode (manual)

Run `update.ps1` to refresh model IDs in your local copies without re-installing:

```powershell
# Dry run (shows what would change):
powershell -ExecutionPolicy Bypass -File templates/update.ps1 -ProjectPath "C:\path\to\project"

# Apply changes:
powershell -ExecutionPolicy Bypass -File templates/update.ps1 -ProjectPath "C:\path\to\project" -Apply
```

To install a newer version of the full library in copy mode, re-run `setup.ps1` with `-Mode copy -PinVersion v1.2`.

---

## Quick reference

| Goal | Command |
|------|---------|
| Install via plugin (pinned) | `/plugin install agentic-claude@agentic-claude-lib` |
| Bootstrap new project | `powershell -File templates/setup.ps1` |
| Update agent model IDs | `powershell -File templates/update.ps1 -Apply` |
| Uninstall | Remove `.claude/agents/` and `.claude/skills/` from the project directory |
| List installed versions | `git tag -l -n1` (in the library repo) |

---

## GitLab migration note

When the repo moves to `git-scm.tcsgroup.ch`, update the marketplace source in `.claude-plugin/marketplace.json`:

```json
"source": {
  "source": "url",
  "url": "https://git-scm.tcsgroup.ch/<group>/Claude-Agents.git",
  "ref": "v1.2"
}
```

Everything else in the plugin setup flow stays identical.
