# Agentic-Claude — Reusable Agent & Skill Library

## Purpose

This repository provides a reusable library of **agent definitions**, **skills**, and **team compositions** for Claude Code. Any project can adopt these agents by copying or symlinking the relevant folders into its `.claude/` directory.

## Repository Structure

```
agents/                  # Subagent definitions (AGENT.md)
  architect/             # Integration architecture analysis, dependency mapping, pattern documentation
  business-analyst/      # Requirements elicitation and formalisation (user stories, FRS, process models)
  developer/             # SOLID, Clean Code, production code only
  tester/                # ISTQB-aligned, pytest, test execution
  devops/                # GitHub Actions, Azure, Docker, CI/CD
  documentarian/         # Context maintenance, docs, ADRs
  product-owner-assistant/ # Coordination, prioritization, no code
  library-maintainer/          # Maintains entire library: definitions, scripts, hooks, installer (repo-improvement-team only)

artefacts/               # Artefact ownership registry (RACI + quality gates + lifecycle)
  architecture-decision-record.yaml
  high-level-design.yaml
  target-architecture.yaml
  integration-pattern-catalog.yaml
  system-context-diagram.yaml
  requirements-specification.yaml
  api-specification.yaml
  detailed-design.yaml
  test-plan.yaml
  test-cases.yaml
  postman-collection.yaml
  deployment-plan.yaml
  software-bill-of-materials.yaml

skills/                  # Reusable slash-command skills (SKILL.md)
  agile-user-stories/          # /agile-user-stories — Connextra stories, INVEST, Gherkin AC, Jira creation
  archimate-generation/        # /archimate-generation — Lucidchart→YAML→.archimate via Python generator
  architecture-decision-records/  # /architecture-decision-records — Nygard ADR authoring and lifecycle
  business-process-modeling/   # /business-process-modeling — BPMN 2.0 AS-IS/TO-BE process diagrams
  develop/               # /develop — implement a feature from spec
  test/                  # /test — run and analyze test results
  deploy/                # /deploy — CI/CD pipeline operations
  enterprise-architecture-framework/  # /enterprise-architecture-framework — TOGAF/ArchiMate domain scoping
  integration-patterns/        # /integration-patterns — EIP pattern selection and documentation
  requirements-analysis/       # /requirements-analysis — IEEE 830 / BABOK requirements elicitation
  review/                # /review — code review checklist
  document/              # /document — update project documentation
  security-audit/              # /security-audit — OWASP Top 10, CVEs, IBM APIC/ACE security hardening
  security-by-design/          # /security-by-design — STRIDE threat modelling, OWASP, TCS baseline
  use-case-modeling/           # /use-case-modeling — UML use cases, Cockburn format, Gherkin BDD
  postman-collection-generator/  # /postman-collection-generator — API test collections
  publish-confluence/    # /publish-confluence — publish docs to Confluence as a page tree
  pattern-diagram-design/  # /pattern-diagram-design — TCS integration-pattern Mermaid diagrams (ARCHI/EIP)

teams/                   # Team composition definitions
  feature-team.md        # Developer + Tester + Documentarian
  release-team.md        # DevOps + Tester + Documentarian
  full-team.md           # All agents
  repo-improvement-team.md # PO + Documentarian + Developer — improve this library itself

knowledge/               # Central technology knowledge base — packs by platform taxonomy (group/platform/<technology>.md); skills stay agnostic and reference packs. NOT enumerated in the inventory; governed by a generated index + planned conformance lint. See knowledge/README.md

templates/               # Project installation templates
  project-claude.md      # Template CLAUDE.md for consuming projects
  settings.json          # Template settings with hooks
  hooks/                 # Ready-to-use hook templates (copy blocks into .claude/settings.json)
    pii-guard.json       # UserPromptSubmit — blocks PII input (LPD/RGPD TCS policy)
    auto-test.json       # PostToolUse — runs pytest after every Write/Edit
    auto-format.json     # PostToolUse — runs black + ruff on edited Python files
    security-scan.json   # PostToolUse — runs bandit on edited Python files
    agent-pipeline.json  # SubagentStop — chains all 6 agents with signal messages
    confluence-publish.json # PostToolUse — publishes index.html to Confluence on save
    commit-guard.json    # PreToolUse — warns before dangerous git commands
    notify-on-stop.json  # Stop — desktop notification when Claude finishes
    scripts/
      pii_check.py       # PII detection script used by pii-guard.json
  project.code-workspace # Template VS Code multi-root workspace
  install.ps1            # PowerShell installer (copy or symlink mode)
  setup.ps1              # One-shot bootstrap (agents + skills + workspace + CLAUDE.md + .gitignore)
  update.ps1             # Model auto-updater (detects outdated model IDs, applies latest)

docs/                    # Documentation
  installer/             # Installer guide: usage, examples, troubleshooting
  memory/                # Memory architecture design: scope, sharing, consolidation
  howto/                 # Step-by-step setup guides
    PLUGIN-SETUP.md      # Plugin-native install, bootstrap, and update reference
    AGENT-AUTHORING.md   # How to create a new agent
    SKILL-AUTHORING.md   # How to create a new skill
    TEAM-AUTHORING.md    # How to create a new team

.claude-plugin/          # Claude Code plugin packaging
  plugin.json            # Plugin manifest (name, semver version, metadata)
  marketplace.json       # Marketplace catalog entry (source + version pin)

.claude/                 # This repo's own Claude config (versioned)
  settings.json          # Wires the commit-guard PreToolUse hook
  hooks/pre-commit-guard.ps1 # Commit guard (Windows default): inventory sync + frontmatter lint
  hooks/pre-commit-guard.js  # Cross-platform (Node) twin for macOS/Linux
```

## Design Principles

1. **Agents are roles, not projects** — Agent definitions contain domain expertise (SOLID, ISTQB, TOGAF) but zero project-specific knowledge.
2. **Skills are workflows, not instructions** — Skills define step-by-step procedures that any agent can invoke.
3. **Teams are compositions** — Team definitions document which agents to spawn together for common workflows.
4. **Tool restriction enforces separation** — Each agent only has access to tools matching its responsibility.
5. **Memory enables learning** — Agents use `memory: project` to accumulate patterns within each project. See [`docs/memory/DESIGN.md`](docs/memory/DESIGN.md) for the full memory architecture.
6. **Progress reporting prevents stalls** — Every agent reports checkpoints; the orchestrator synthesizes before spawning more work.
7. **Output discipline preserves context** — Agents summarize findings instead of dumping raw output; status updates stay under 2000 characters.

## Installation into a Project

### Automated (Recommended)

Use `setup.ps1` for a one-shot install of everything (agents, skills, workspace, hooks, CLAUDE.md, .gitignore). See [`docs/howto/PLUGIN-SETUP.md`](docs/howto/PLUGIN-SETUP.md) for the full guide including plugin-native installation.

```powershell
# One-shot bootstrap (interactive — asks for project path):
powershell -ExecutionPolicy Bypass -File templates/setup.ps1

# Silent mode (all defaults, symlink mode):
powershell -ExecutionPolicy Bypass -File templates/setup.ps1 -ProjectPath "C:\path\to\project" -Silent

# For selective installs or uninstall, use the lower-level installer:
powershell -ExecutionPolicy Bypass -File templates/install.ps1 -ProjectPath "." -Agents developer,tester -Skills develop,test -IncludeHooks
powershell -ExecutionPolicy Bypass -File templates/install.ps1 -ProjectPath "C:\path\to\project" -Uninstall
```

### Manual (Unix/Mac)

```bash
# From your project root:
mkdir -p .claude/agents .claude/skills

# Symlink for auto-updates
ln -s /path/to/Agentic-Claude/agents/developer .claude/agents/developer
ln -s /path/to/Agentic-Claude/agents/tester .claude/agents/tester
ln -s /path/to/Agentic-Claude/skills/develop .claude/skills/develop
ln -s /path/to/Agentic-Claude/skills/test .claude/skills/test

# Or copy (static snapshot)
cp -r /path/to/Agentic-Claude/agents/developer .claude/agents/
cp -r /path/to/Agentic-Claude/skills/develop .claude/skills/
```

## Multi-Project Setup

When sharing this library across multiple projects, the recommended architecture is:

```
GitHub/
  Claude Agents/          # This repo — shared AI tools library
  ProjectA/               # Consuming project A
    .claude/
      agents/ -> junctions to Claude Agents/agents/*
      skills/ -> junctions to Claude Agents/skills/*
      settings.json        # Project-specific hooks & permissions
    CLAUDE.md              # Project-specific context
    .env                   # Project-specific secrets
    .venv/                 # Project-specific Python environment
  ProjectB/               # Consuming project B (same pattern)
```

### Key Principles

| Concern | Where it lives | Shared? |
|---------|---------------|---------|
| Agent definitions (AGENT.md) | Claude Agents repo | Yes — via symlinks |
| Skill workflows (SKILL.md) | Claude Agents repo | Yes — via symlinks |
| Team compositions | Claude Agents repo | Yes — referenced, not installed |
| `.claude/settings.json` | Each project | No — project-specific hooks/permissions |
| `CLAUDE.md` | Each project root | No — project-specific context |
| `.env` | Each project | No — project-specific secrets |
| Python `.venv/` | Each project | No — project-specific dependencies |
| VS Code workspace | Each project | No — but use `templates/project.code-workspace` as starting point |

### VS Code Workspace (Required for Team Discoverability)

Each consuming project **must** have a multi-root `.code-workspace` file. This is not optional — without it, team compositions (`teams/*.md`) are not visible from the project directory, and agent teams cannot be orchestrated.

#### Why It's Required

| Without workspace | With workspace |
|-------------------|----------------|
| Only `.claude/agents/` and `.claude/skills/` visible (via symlinks) | Full library visible: agents, skills, **teams**, templates |
| Team compositions not discoverable | Claude can read `teams/feature-team.md` etc. to spawn teams |
| No `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var | Agent teams enabled via workspace terminal settings |
| Two separate VS Code windows | Single window with both repos |

#### Setup for a New Project

1. Copy the template into your project:
   ```powershell
   Copy-Item "C:\path\to\Claude Agents\templates\project.code-workspace" "C:\path\to\Project\Project.code-workspace"
   ```

2. Edit the file — rename the `"Project"` folder name and adjust `"path"` if needed:
   ```jsonc
   {
       "folders": [
           { "name": "AI Tools", "path": "../Claude Agents" },
           { "name": "MyProject", "path": "." }
       ],
       "settings": {
           "terminal.integrated.env.windows": {
               "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
           },
           "files.exclude": {
               "**/.git": true,
               "**/.DS_Store": true,
               "**/Thumbs.db": true
           },
           "search.exclude": {
               ".venv/**": true,
               "node_modules/**": true,
               "htmlcov/**": true,
               ".pytest_cache/**": true,
               "__pycache__/**": true
           }
       }
   }
   ```

3. Open in VS Code: **File → Open Workspace from File** → select the `.code-workspace` file.

4. Run Claude Code from the **project folder** in the integrated terminal (not from the AI Tools folder).

#### Key Settings Explained

- **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`** — Enables the experimental agent teams feature so Claude can spawn parallel agents from team compositions.
- **`"name": "AI Tools"`** — The first folder should always be named `"AI Tools"` and point to this repo. This is a convention across all projects.
- **`search.exclude`** — Prevents VS Code search from indexing virtual environments, caches, and coverage reports.

#### Workspace File Conventions

- **File name:** `<ProjectName>.code-workspace` (e.g., `CMDB_to_Archimate.code-workspace`)
- **Location:** Project root (committed to git)
- **AI Tools path:** Relative path to this repo (typically `"../Claude Agents"` when repos are siblings)
- **Add project-specific settings** like `python.defaultInterpreterPath` to the workspace settings block

### .gitignore for Consuming Projects

Symlinked agents/skills should not be committed to the project repo. Add to `.gitignore`:

```gitignore
# Claude agent/skill symlinks (managed by Agentic-Claude library)
.claude/agents/
.claude/skills/

# Keep settings.json tracked (project-specific)
!.claude/settings.json

# Claude local files
.claude/settings.local.json
CLAUDE.local.md

# Claude memory (transient runtime data)
.claude/memory/checkpoints/
```

### Running Claude Code

Always run Claude Code from the **project directory** (not the library directory). Claude reads `.claude/` relative to the working directory, so it picks up agents/skills via the junctions while using the project's own `CLAUDE.md` for context.

## Agent Teams (Experimental)

To use Agent Teams for parallel collaboration:

```bash
# Enable experimental agent teams
set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
claude
```

Then ask Claude to create a team:
> "Create a feature team with developer, tester, and documentarian to implement X"

Claude will read the team composition from `teams/feature-team.md` and spawn the appropriate agents.

## Self-Maintaining Inventory

**IMPORTANT — Keep this section up to date.** Whenever an agent, skill, or team is added, removed, or modified in this repository, this CLAUDE.md MUST be updated to reflect the change. Before completing any session that modifies `agents/`, `skills/`, or `teams/`, verify that:

1. The **Repository Structure** tree above lists all current agents, skills, and teams
2. The tables below accurately describe each agent and skill
3. No stale entries remain for deleted items

If you notice this file is out of sync with the actual folder contents, fix it immediately.

### Agent Inventory

| Agent | Version | Model | Memory | Tools | Description |
|-------|---------|-------|--------|-------|-------------|
| `developer` | 1.1.0 | opus | project | Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch, WebFetch, NotebookEdit | Implements features following SOLID/Clean Code. No tests, docs, or deploy. |
| `tester` | 1.1.0 | opus | project | Read, Write, Edit, Bash, Grep, Glob, Task | ISTQB-aligned test creation and execution. No production code. |
| `devops` | 1.1.0 | opus | project | Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch, WebFetch | GitHub Actions, Azure, Docker, CI/CD, SBOM. No app code or tests. |
| `documentarian` | 1.1.0 | sonnet | project | Read, Write, Edit, Grep, Glob, Task, WebSearch | Maintains CLAUDE.md, ADRs, docs. Consolidates team-findings.md. |
| `product-owner-assistant` | 1.2.0 | opus | project | Read, Grep, Glob, Task, WebSearch, WebFetch, TodoWrite, AskUserQuestion, mcp__claude_ai_Atlassian__* | Coordinates agents, manages backlog, writes session handoffs. Never codes. Atlassian MCP (Confluence/Jira) granted; MCP server name may differ per environment. |
| `architect` | 1.0.0 | opus | project | Read, Write, Edit, Grep, Glob, Task, WebSearch, WebFetch, TodoWrite | Analyzes integration architectures (APIC/ACE/MQ), maps dependencies, documents patterns. No app code or tests. |
| `archimate-architect` | 1.0.0 | opus | project | Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch, WebFetch, mcp__claude_ai_Lucid__* | Produces ArchiMate target-architecture files (.archimate) from Lucidchart diagrams or YAML manifests. TCS-specific. |
| `business-analyst` | 1.0.0 | opus | project | Read, Write, Edit, Grep, Glob, Task, WebSearch, WebFetch, TodoWrite, AskUserQuestion, mcp__claude_ai_Atlassian__* | Elicits and formalises requirements (user stories, FRS, process models). Bridges PO intent and technical solution. |
| `library-maintainer` | 1.0.0 | opus | project | Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch, WebFetch | Maintains the entire library — definitions, artefacts, scripts, hooks, installer. Repo-improvement-team only. |

### Skill Inventory

| Skill | Version | Invocation | Type | Category | Description |
|-------|---------|-----------|------|----------|-------------|
| `agile-user-stories` | 1.0.0 | `/agile-user-stories` | methodological | business-analysis | Write, split, and refine user stories (Connextra/INVEST/MoSCoW/Gherkin). Creates stories in Jira via Atlassian MCP. |
| `architecture-decision-records` | 1.0.0 | `/architecture-decision-records` | methodological | architecture | Author ADRs in Nygard format with lifecycle management (draft→proposed→accepted→superseded). |
| `business-process-modeling` | 1.0.0 | `/business-process-modeling` | methodological | business-analysis | Model AS-IS/TO-BE business processes in BPMN 2.0 notation using Mermaid diagrams. |
| `enterprise-architecture-framework` | 1.0.0 | `/enterprise-architecture-framework` | methodological | architecture | Apply TOGAF/ArchiMate discipline: domain scoping, viewpoint selection, governance gates. |
| `integration-patterns` | 1.0.0 | `/integration-patterns` | methodological | architecture | Select and document EIP integration patterns (messaging, routing, transformation, reliability). |
| `requirements-analysis` | 1.0.0 | `/requirements-analysis` | methodological | business-analysis | Elicit, classify, and write IEEE 830 requirements with SMART/MoSCoW/Given-When-Then criteria. |
| `security-by-design` | 1.0.0 | `/security-by-design` | methodological | security | STRIDE threat modelling, OWASP controls, TCS security baseline enforcement. |
| `use-case-modeling` | 1.0.0 | `/use-case-modeling` | methodological | business-analysis | Identify actors and use cases (UML/Cockburn), write Gherkin BDD acceptance criteria. |
| `develop` | 1.1.0 | `/develop` | methodological | software-engineering | Feature implementation workflow: explore, plan, implement, report |
| `test` | 1.1.0 | `/test` | methodological | quality-assurance | Test execution and validation: run, analyze failures, write missing tests |
| `archimate-generation` | 1.0.0 | `/archimate-generation` | technological | modelling | End-to-end: reads Lucidchart diagrams or a YAML manifest, generates target-architecture.yaml, runs the Python generator to produce a .archimate file for the Archi tool. |
| `deploy` | 1.1.0 | `/deploy` | technological | devops-toolchain | CI/CD and deployment: assess infra, implement pipelines, validate configs |
| `review` | 1.1.0 | `/review` | methodological | software-engineering | Code review checklist: architecture, quality, security, Python-specific |
| `document` | 1.1.0 | `/document` | methodological | documentation | Documentation sync: detect changes, update CLAUDE.md, create ADRs |
| `security-audit` | 1.2.0 | `/security-audit` | methodological | security | Dedicated OWASP Top 10 audit: secrets, CVEs, injection, auth, cryptography, APIC/ACE security |
| `postman-collection-generator` | 1.0.1 | `/postman-collection-generator` | technological | testing-tools | Generate Postman v2.1 collections for API non-regression testing (APIC/ACE/MQ) |
| `publish-confluence` | 1.1.1 | `/publish-confluence` | technological | documentation-platform | Publish docs/presentation to Confluence as a read-only, emoji-titled page tree (native ADF; object version in each detail-page title, plugin version on root; SVG→Mermaid diagrams; agent→skill cross-links) |
| `pattern-diagram-design` | 1.0.1 | `/pattern-diagram-design` | technological | integration-middleware | Generate TCS integration-pattern diagrams as Mermaid, aligned to the ARCHI catalog and EIP vocabulary (sync/async, proxies, channels, routing, MFT/ETL/ELT, retry/replay) |

### Team Inventory

| Team | Version | Agents | Use Case |
|------|---------|--------|----------|
| `feature-team` | 1.1.0 | developer + tester + documentarian | Implement a feature end-to-end |
| `release-team` | 1.1.0 | devops + tester + documentarian | Prepare and validate a release |
| `full-team` | 1.1.0 | all 6 agents | Major features, bootstrapping, migrations |
| `repo-improvement-team` | 1.0.0 | product-owner-assistant (lead) + library-maintainer | The only team that may modify this library. Recommends improvements to a human, applies approved ones, refreshes the wiki; human commits. |

## Artefact Registry

Central ownership registry for all long-term project artefacts. Each file in `artefacts/` defines: format, storage pattern, RACI ownership, quality-gate checklist, and lifecycle transitions.

| Artefact | Alias | Owner (R) | Accountable (A) | Format |
|---|---|---|---|---|
| architecture-decision-record | ADR | architect | product-owner-assistant | markdown |
| high-level-design | HLD | architect | product-owner-assistant | markdown |
| target-architecture | Target Arch | archimate-architect | architect | archimate |
| integration-pattern-catalog | IPC | architect | architect | markdown |
| system-context-diagram | SCD | architect | product-owner-assistant | plantuml |
| requirements-specification | BRD/FRS | business-analyst | product-owner-assistant | markdown |
| api-specification | API Spec | developer | architect | openapi |
| detailed-design | LLD | developer | architect | markdown |
| test-plan | TP | tester | product-owner-assistant | markdown |
| test-cases | TC | tester | tester | markdown |
| postman-collection | NRC | tester | tester | json |
| deployment-plan | DP | devops | product-owner-assistant | markdown |
| software-bill-of-materials | SBOM | devops | devops | json |

## Self-Improvement Workflow

Library definitions are shared by every consuming project, so this repo is improved through **one dedicated team — never ad-hoc edits.**

**Only the [`repo-improvement-team`](teams/repo-improvement-team.md) may modify this repo.** Its modifying agent — [`library-maintainer`](agents/library-maintainer/AGENT.md), which maintains definitions, docs, scripts, installer, and hooks — **belongs only to this team** and is the only agent whose workspace is this repo. Every other agent keeps its "AI Tools repo is read-only" guard. Skills, by contrast, are shared by all agents.

The team works **recommendation-first**:
1. **Recommend** — analyse the library (definitions, docs, `team-findings.md`, recent sessions) and present a prioritised improvement *recommendation* to the human. No edits.
2. **Human approves** which items to apply.
3. **Apply** — approved items only: edit definitions/scripts, sync the **Self-Maintaining Inventory** above (Repository Structure + Agent/Skill/Team tables), validate, then refresh the wiki via [`/publish-confluence`](skills/publish-confluence/SKILL.md).
4. **Human commits & pushes** — the team never commits on its own.

**Enforcement (versioned):** a `PreToolUse` hook wired through [`.claude/settings.json`](.claude/settings.json) blocks a `git commit` in this repo whenever (a) the CLAUDE.md inventory lists fewer agents/skills/teams than exist on disk, or (b) an `AGENT.md`/`SKILL.md` is missing `name:`/`description:` frontmatter. It gates only this repo (never another), and a human is always the committer — the real guardrail against a self-modifying library drifting unreviewed.

The guard ships in two equivalent forms: [`pre-commit-guard.ps1`](.claude/hooks/pre-commit-guard.ps1) (the default — PowerShell is always present on Windows) and [`pre-commit-guard.js`](.claude/hooks/pre-commit-guard.js) (a Node twin). **On macOS/Linux**, switch the `settings.json` command to `node "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-commit-guard.js"` (PowerShell isn't installed there by default; `node` ships with Claude Code). Keeping the two in sync is part of the repo-improvement-team's remit.

## Agent Coordination Protocols

All agents and teams follow these protocols to prevent context window exhaustion and ensure the orchestrator (product-owner-assistant) stays informed:

### Progress Reporting
Every agent reports at: **Start**, **After each major action**, **On blockers**, and **Completion**. Status updates stay under 2000 characters and use structured formats (tables, bullet points, file:line references).

### Output Discipline
Agents never dump full file contents or raw command output. They summarize findings and reference file:line locations. This prevents context window overflow during multi-agent workflows.

### Parallel Execution Limits
- **Maximum 2 agents in parallel** at any time
- Exploration tasks run sequentially (one agent at a time)
- The orchestrator synthesizes results before spawning the next batch
- If accumulated output exceeds 5 agent responses in one phase, pause and summarize

### Error Escalation
Agents report BLOCKED with details. The orchestrator pauses dependent work and presents options to the PO (human). No silent workarounds.

### Crash Recovery
Every agent persists progress checkpoints to `.claude/memory/checkpoints/active.md` (append-only) during team workflows. If a session crashes, the next session reads this file to detect and resume the interrupted workflow. The orchestrator (PO assistant or team lead) manages the checkpoint lifecycle: creates the file at workflow start, presents recovery options on crash detection, and deletes it after successful completion. Checkpoints are transient — they are not committed to git. See each agent's "Crash-Recovery Checkpoints" section and each team's "Crash Recovery" section for details.

### Memory & Knowledge Sharing
All agents use `memory: project` — knowledge stays scoped to the project, preventing cross-project contamination. Agents write cross-team discoveries to `.claude/memory/team-findings.md`. The documentarian consolidates these into CLAUDE.md during `/document` runs. The PO assistant writes session handoff summaries to `.claude/memory/sessions/` after multi-agent workflows. Agents also persist crash-recovery checkpoints to `.claude/memory/checkpoints/active.md` during active workflows (transient, deleted on completion). See [`docs/memory/DESIGN.md`](docs/memory/DESIGN.md) for the full architecture.

## Versioning

This library uses git tags for stable releases. Consuming projects can either follow HEAD (via symlinks) or pin to a specific version (via copy mode).

Current version: **v1.2.1**

### Release History

| Tag | Description |
|-----|-------------|
| `v1.2.1` | Informational per-object versioning (semver in each agent/skill/team frontmatter); commit-guard twin-parity + bump-on-change; model aliases made first-class in the validator; Confluence object-version titles & banners |
| `v1.2` | Agent model upgrades (opus-4-8), setup.ps1 bootstrap, update.ps1 auto-updater, architect in full-team, plugin how-to |
| `v1.1` | Memory architecture: project scope, team sharing, session handoffs |
| `v1.0` | First stable release: agents, skills, teams, installer, workspace support |

```powershell
# List available versions
git tag -l -n1
```

To install or update, see the [plugin setup guide](docs/howto/PLUGIN-SETUP.md).

### Keeping agents on the latest Claude models

Run `update.ps1` (dry-run by default, add `-Apply` to write changes):

```powershell
# Check what would change:
powershell -ExecutionPolicy Bypass -File templates/update.ps1

# Apply model updates:
powershell -ExecutionPolicy Bypass -File templates/update.ps1 -Apply
```

The `$ModelMap` table in `update.ps1` must be updated whenever Anthropic releases new model IDs.

## Plugin & Marketplace Distribution

This library is packaged as a **Claude Code plugin** so consuming projects can pin a specific version instead of always tracking HEAD. The whole bundle (agents + skills + teams) is the single **installable/pinnable** unit, versioned by one plugin semver — Claude Code has no mechanism to install or pin an individual agent or skill. Each object *additionally* carries an informational `version:` in its frontmatter (see [Plugin & object versions](#plugin--object-versions--what-a-plugin-is-and-how-versioning-works) below), but those are descriptive only and never alter how the plugin installs.

- **Plugin manifest**: [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) — `name: agentic-claude`, `version: 1.2.0` (semver). The plugin auto-discovers `agents/`, `skills/`, and `commands/` at the repo root.
- **Marketplace catalog**: [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) — `name: agentic-claude-lib`, currently sourced from GitHub (`Aletheia-Thomas/Claude-Agents`) pinned to git tag `v1.2.0`.

### Consuming the plugin

```text
# Add the marketplace (reads marketplace.json from the repo's default branch)
/plugin marketplace add Aletheia-Thomas/Claude-Agents

# Install the plugin — pinned to the version in the marketplace entry (tag v1.2.0)
/plugin install agentic-claude@agentic-claude-lib
```

To pin a project to a specific version, set it in the project's `.claude/settings.json` (project scope **overrides** user scope, so different projects can pin different versions simultaneously):

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

### Two ways to consume — pick per project

| Mode | How | Behaviour |
|------|-----|-----------|
| **Track latest** (personal dev) | User-level junctions: `~/.claude/agents` → this repo's `agents/`, `~/.claude/skills` → `skills/` | Always HEAD; new agents/skills appear automatically; every project sees them |
| **Pinned** (reproducible) | Enable the plugin at **project** scope pinned to a tag | Frozen to that version; updates only when the pin is bumped; overrides the user-level "latest" for that project |

### Plugin & object versions — what a plugin is and how versioning works

Two kinds of version live in this repo, and they do different jobs:

- **Plugin version (the one that matters to Claude Code).** The *plugin* is the single installable, pinnable unit. Claude Code discovers its contents through [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json), which auto-discovers `agents/`, `skills/`, and `commands/` at the repo root. A consuming project adds the marketplace ([`marketplace.json`](.claude-plugin/marketplace.json)) and pins a version in its own `.claude/settings.json`. There is exactly **one** semver for the whole bundle (`plugin.json` `version`, mirrored by a git tag). Think of the plugin release as the **train**: everything ships together, and the train number is the only thing you can board or pin to.

- **Object versions (informational only).** Every agent, skill, and team additionally carries its own `version:` in its frontmatter. These are bumped **when that specific object changes**, so a human can see at a glance what moved between releases. They are the **manifest of what changed** on the train — they are **not** independently installable or pinnable, and Claude Code never acts on them. The inventory tables above and the Confluence pages surface these; frontmatter is the single source of truth (no separate `VERSIONS.md`).

When cutting a release: bump any object `version:` that changed, then bump the plugin `version` in `plugin.json` and the `ref`/`version` in `marketplace.json`, then tag.

### Notes

- **Tag naming**: the marketplace `ref` points at the full semver tag `v1.2.1`. Always use full semver tags (`v1.2.1`, `v1.3.0`) so the git tag and the plugin `version` field line up exactly.
- **GitLab migration**: when the repo moves to `git-scm.tcsgroup.ch`, switch the marketplace entry `source` to `{ "source": "url", "url": "https://git-scm.tcsgroup.ch/<group>/<repo>.git", "ref": "v1.2.1" }` — the rest stays the same.
- Whenever a new release tag is cut, bump `version` in `plugin.json` and update the `ref`/`version` in `marketplace.json` to match. You can automate this with `update.ps1 -BumpVersion -Apply`.

## Compatibility

- Claude Code CLI (any version with subagent support)
- Works with: Claude Pro, Claude Max, Claude for Teams, Claude for Enterprise
- No API key required (subscription OAuth is sufficient)
