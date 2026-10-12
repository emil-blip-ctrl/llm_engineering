# Changelog

All notable changes to **Agentic-Claude** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [1.2.0] — 2026-06-03

### Added
- **`templates/setup.ps1`** — One-shot bootstrap script. Installs all agents, skills, workspace file, hooks, CLAUDE.md template, `.gitignore` entries, and memory scaffold in a single command. Replaces the need to call `install.ps1` with multiple flags. Supports interactive and silent (`-Silent`) modes, symlink and copy modes, and optional version pinning.
- **`templates/update.ps1`** — Model auto-updater. Dry-runs by default; shows which `model:` directives in `AGENT.md` files are outdated and replaces them with the latest Claude model IDs when run with `-Apply`. Supports both library agents and project copy-mode agents via `-ProjectPath`. Optionally bumps `plugin.json` / `marketplace.json` with `-BumpVersion`.
- **`docs/howto/PLUGIN-SETUP.md`** — End-to-end guide for the plugin-native setup flow (`/plugin marketplace add` + `/plugin install`), including version pinning, workspace configuration, and a quick-reference command table.
- **Architect agent added to `teams/full-team.md`** — The architect was listed in the agent inventory but was missing from the full-team composition. Now included with its role (Integration Analyst), file boundaries (`docs/architecture/`, `docs/adr/`), and workflow position (Phase 1, before developer).

### Changed
- **All Opus agents upgraded**: `claude-opus-4-6` → `claude-opus-4-8` (developer, tester, devops, product-owner-assistant, architect). Documentarian stays on `claude-sonnet-4-6` (latest Sonnet).
- **Developer agent**: Added `NotebookEdit` to the tools list for Jupyter notebook support. Added explicit instruction to read `team-findings.md` before starting implementation.
- **Tester agent**: Added `httpx`/`respx` async API testing guidance. Added mutation testing step (`mutmut`) for high-coverage projects. Added `team-findings.md` infrastructure check before writing new tests.
- **DevOps agent**: Added SBOM generation step (`syft` / `cyclonedx`) to the standard pipeline stages alongside existing security scanning.
- **PO Assistant agent**: Added Architect to the delegation table so the PO knows when and how to delegate integration analysis tasks.
- **`full-team.md`** workflow, task pattern, file boundaries, and parallel execution diagram updated to include architect.
- **`plugin.json`** version: `1.1.0` → `1.2.0`.
- **`marketplace.json`** ref: `v1.1` → `v1.2`, version: `1.1.0` → `1.2.0`.

- **`templates/setup.sh`** — Unix/Mac equivalent of `setup.ps1`. Same feature set: symlink/copy mode, project type detection, workspace generation, CLAUDE.md from template, `.gitignore` scaffold.
- **`.gitattributes`** — Forces LF for all text files, CRLF for `.ps1`/`.bat` only. Eliminates line-ending warnings on every push.
- **`.github/workflows/validate.yml`** — CI validation: checks all `AGENT.md` fields (`name`, `model`, `tools`, `memory`), warns when model IDs are not in the known-latest list, validates `plugin.json` + `marketplace.json` structure and version consistency, validates `SKILL.md` fields.
- **`.github/workflows/release.yml`** — Automated GitHub Release on version tag push. Extracts matching `CHANGELOG.md` section as release notes, validates `plugin.json` version matches the tag.
- **`skills/develop/SKILL.md`** — 7-step workflow with OWASP security checklist, CLAUDE.md + team-findings.md read step, NotebookEdit guidance, structured self-review, and team-findings.md write step.
- **`skills/review/SKILL.md`** — Full rewrite: severity levels (🔴/🟡/🔵), performance checklist, IBM APIC/ACE/MQ integration checklist, JS/TS checks, git hygiene section, structured verdict.
- **`skills/test/SKILL.md`** — 7-step workflow: multi-language (pytest/Jest/Maven), infrastructure check from team-findings.md, async mocking patterns (respx+httpx), mutation testing with mutmut, team-findings.md write step.

### Changed
- **`templates/settings.json`** — Complete hooks overhaul:
  - `PreToolUse`: blocks `git push` to main/master with clear error message
  - `PostToolUse(Write|Edit)`: remind to run /test
  - `PostToolUse(git commit)`: remind to push branch
  - `PostToolUse(git push)`: remind to open PR
  - `SubagentStop` for all 6 agents: orchestration prompts guiding the next step
  - `Notification`: appends all Claude notifications to `.claude/memory/notifications.log`
  - `Stop`: end-of-session reminder (commit, /test, /document)
  - Expanded `allow` list: `NotebookEdit`, git operations, `gh release`, `find/cp/mv`, `mvn`, `docker run`
  - Expanded `deny` list: `git push -f`, `git commit --amend`, `curl | bash`, `eval`
- **`teams/feature-team.md`**: added optional architect note with trigger condition and updated workflow.
- **`teams/release-team.md`**: added optional architect note for API contract / APIC version changes.
- **`templates/project-claude.md`**: complete rewrite — integration points table, env vars table, tech stack table, known gotchas, per-agent instruction block.
- **`templates/install.ps1`**: added deprecation notice at top redirecting to `setup.ps1`.
- **`.claude-plugin/plugin.json`**: added `engines: { "claude-code": ">=1.0.0" }` field.
- **`docs/memory/DESIGN.md`**: status DRAFT → Implemented (v1.1+).

### Migration from v1.1
No breaking changes. Existing symlink installations pick up all agent and skill improvements automatically. Existing copy-mode installations can run `update.ps1 -Apply` to refresh model IDs.

---

## [1.1.0] — 2025 Q4

### Added
- Memory architecture: `memory: project` scope for all agents (prevents cross-project contamination).
- `team-findings.md` convention for cross-agent discovery sharing.
- Session handoff protocol — PO assistant writes `.claude/memory/sessions/YYYY-MM-DD-<slug>.md` after multi-agent workflows.
- Crash-recovery checkpoints — all agents append to `.claude/memory/checkpoints/active.md` during team workflows.
- `teams/feature-team.md`, `teams/release-team.md`, `teams/full-team.md` — team composition blueprints.
- `docs/memory/DESIGN.md` — full memory architecture design document.

### Changed
- All agents: memory scope changed from `user` to `project`.
- `product-owner-assistant`: full crash recovery protocol with resume/restart/review options.

---

## [1.0.0] — 2025 Q3

### Added
- Initial release: 6 agent definitions (developer, tester, devops, documentarian, product-owner-assistant, architect).
- 6 skill workflows (develop, test, deploy, review, document, postman-collection-generator).
- `templates/install.ps1` — PowerShell installer with symlink and copy modes.
- `templates/project-claude.md` — CLAUDE.md template for consuming projects.
- `templates/settings.json` — Hook and permission template.
- `templates/project.code-workspace` — VS Code multi-root workspace template.
- `.claude-plugin/` — Claude Code plugin manifest and marketplace catalog.
- `docs/installer/README.md` — Installer guide.
