# Installer Guide

## What It Does

`templates/install.ps1` wires a project to the shared Claude Agents library. It creates the `.claude/agents/` and `.claude/skills/` directories inside your project and populates them — either as **directory junctions** (live links back to this repo) or as **static copies**.

After installation, Claude Code sees your project's agents and skills when you run it from the project directory. No manual `mklink` commands, no copying folders by hand.

## When to Use It

| Situation | Use the installer? |
|-----------|-------------------|
| Onboarding a **new project** for the first time | Yes |
| Adding an agent/skill to an **existing project** | Yes (re-run with specific `-Agents` / `-Skills`) |
| Day-to-day development | No — just open your `.code-workspace` file |
| Updating agents after library changes | No — junctions follow HEAD automatically. If you used copy mode, re-run the installer. |
| Removing Claude Agents from a project | Yes — use `-Uninstall` |

## Prerequisites

- PowerShell 5.1+ (built into Windows 10/11)
- No admin rights required (directory junctions don't need elevation)
- Both repos cloned as siblings under the same parent folder (e.g., `C:\Users\you\Github\`)

## Quick Start

Open PowerShell in any directory and run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\RT02752\Github\Claude Agents\templates\install.ps1" `
  -ProjectPath "C:\Users\RT02752\Github\MyNewProject" `
  -UseSymlinks `
  -IncludeHooks `
  -IncludeWorkspace
```

This does four things:
1. Creates `.claude/agents/` with junctions to all 5 agents
2. Creates `.claude/skills/` with junctions to all 6 skills
3. Copies `templates/settings.json` → `.claude/settings.json` (permissions and hooks)
4. Generates `MyNewProject.code-workspace` (VS Code multi-root workspace)

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-ProjectPath` | Yes | — | Absolute or relative path to the target project |
| `-Agents` | No | all 5 | Comma-separated list: `developer,tester,devops,documentarian,product-owner-assistant` |
| `-Skills` | No | all 6 | Comma-separated list: `develop,test,deploy,review,document,postman-collection-generator` |
| `-UseSymlinks` | No | `false` | Create directory junctions instead of copying. Recommended for development. |
| `-IncludeHooks` | No | `false` | Copy `templates/settings.json` to `.claude/settings.json`. Skips if file already exists. |
| `-IncludeWorkspace` | No | `false` | Generate a `.code-workspace` file. Skips if file already exists. |
| `-ProjectName` | No | directory name | Custom name for the workspace file and folder label |
| `-Uninstall` | No | `false` | Remove installed agents and skills (handles both junctions and copies) |

## Installation Modes

### Symlink Mode (Recommended)

```powershell
-UseSymlinks
```

Creates **Windows directory junctions** (`mklink /J`). The project's `.claude/agents/developer/` points directly to `Claude Agents/agents/developer/`. When you edit an agent definition in the library, every project sees the change immediately.

Advantages:
- Single source of truth
- No drift between projects
- No re-installation needed after library updates

Caveats:
- Junctions must not be committed to git (add `.claude/agents/` and `.claude/skills/` to `.gitignore`)
- If the library repo moves, junctions break (re-run installer to fix)

### Copy Mode (Default)

Without `-UseSymlinks`, the installer copies the full directory contents. Each project gets a static snapshot. Use this when you need a frozen version that won't change when the library updates.

## Examples

### Full install for a new project

```powershell
powershell -ExecutionPolicy Bypass -File templates/install.ps1 `
  -ProjectPath "C:\Users\RT02752\Github\MyProject" `
  -UseSymlinks -IncludeHooks -IncludeWorkspace
```

### Install only developer + tester agents with their matching skills

```powershell
powershell -ExecutionPolicy Bypass -File templates/install.ps1 `
  -ProjectPath "C:\Users\RT02752\Github\MyProject" `
  -Agents developer,tester `
  -Skills develop,test `
  -UseSymlinks
```

### Add a missing agent to an existing project

```powershell
powershell -ExecutionPolicy Bypass -File templates/install.ps1 `
  -ProjectPath "C:\Users\RT02752\Github\MyProject" `
  -Agents devops `
  -Skills deploy `
  -UseSymlinks
```

The installer only touches the specified agents/skills — it won't remove or overwrite existing ones.

### Generate a workspace file with a custom name

```powershell
powershell -ExecutionPolicy Bypass -File templates/install.ps1 `
  -ProjectPath "C:\Users\RT02752\Github\MyProject" `
  -IncludeWorkspace -ProjectName "My_Project"
```

Creates `My_Project.code-workspace` with the correct relative path to the library.

### Uninstall everything

```powershell
powershell -ExecutionPolicy Bypass -File templates/install.ps1 `
  -ProjectPath "C:\Users\RT02752\Github\MyProject" `
  -Uninstall
```

Removes all agent and skill directories (handles both junctions and copied folders). Does not remove `.claude/settings.json` or the workspace file.

## What Gets Created

After a full install with all options, your project looks like this:

```
MyProject/
  .claude/
    agents/
      developer/     → junction to Claude Agents/agents/developer
      tester/        → junction to Claude Agents/agents/tester
      devops/        → junction to Claude Agents/agents/devops
      documentarian/ → junction to Claude Agents/agents/documentarian
      product-owner-assistant/ → junction to Claude Agents/agents/product-owner-assistant
    skills/
      develop/       → junction to Claude Agents/skills/develop
      test/          → junction to Claude Agents/skills/test
      deploy/        → junction to Claude Agents/skills/deploy
      review/        → junction to Claude Agents/skills/review
      document/      → junction to Claude Agents/skills/document
      postman-collection-generator/ → junction to Claude Agents/skills/postman-collection-generator
    settings.json    (copied from templates/settings.json)
  MyProject.code-workspace  (generated)
```

## Pinning to a Specific Version

By default, symlink mode follows HEAD — every project always uses the latest agents and skills. If you need a project to stay on a known-good version (e.g., before a production release), use **copy mode with a git tag**.

### Available tags

```powershell
cd "C:\Users\RT02752\Github\Claude Agents"
git tag -l -n1
```

### Install a pinned version

```powershell
cd "C:\Users\RT02752\Github\Claude Agents"
git checkout v1.0

# Install as copies (frozen snapshot that won't change)
powershell -ExecutionPolicy Bypass -File templates/install.ps1 `
  -ProjectPath "C:\Users\RT02752\Github\MyProject" `
  -IncludeHooks -IncludeWorkspace

# Switch back to latest
git checkout main
```

This gives the project a static copy of agents and skills as they existed at `v1.0`. The library repo goes back to `main` immediately — only the copied files stay frozen.

### When to pin vs. when to follow HEAD

| Scenario | Mode |
|----------|------|
| Active development — want latest agent improvements | Symlinks (follows HEAD) |
| Pre-release freeze — don't want agent changes mid-release | Copy from a tag |
| Reproducing a past issue — need exact agent behavior | Copy from a tag |
| Multiple projects, different maturity levels | Mix: symlinks for dev, copies for stable |

### Upgrading a pinned project

To move a pinned project to a newer version:

```powershell
cd "C:\Users\RT02752\Github\Claude Agents"
git checkout v1.1   # or whatever the new tag is

powershell -ExecutionPolicy Bypass -File templates/install.ps1 `
  -ProjectPath "C:\Users\RT02752\Github\MyProject"

git checkout main
```

The installer replaces the existing copied directories with the new version.

## What You Still Need to Do Manually

The installer handles the mechanical setup. These steps require human judgement:

1. **Create `CLAUDE.md`** — Copy `templates/project-claude.md` to your project root and fill in the project-specific sections (architecture, tech stack, build commands, etc.)
2. **Update `.gitignore`** — Add `.claude/agents/` and `.claude/skills/` to prevent committing junctions
3. **Customize `settings.json`** — The template has sensible defaults, but you may need to adjust Bash permissions for your project's tooling (e.g., `Bash(dotnet *)`, `Bash(cargo *)`)
4. **Add Python interpreter path** — If using Python, add `"python.defaultInterpreterPath"` to the workspace settings

## Troubleshooting

**Junction creation fails silently:**
The installer falls back to copy mode automatically and prints a yellow warning. This can happen if the target path has special characters or the drive format doesn't support junctions.

**"Agent not found" warning:**
The source agent/skill directory doesn't exist in the library. Check the agent/skill name for typos.

**"settings.json already exists" / "workspace already exists":**
The installer never overwrites these files. Delete them manually first if you want a fresh copy from the template.

**Agents not showing up in Claude Code:**
Make sure you're running Claude from the **project directory**, not the library. Claude reads `.claude/` relative to the current working directory.
