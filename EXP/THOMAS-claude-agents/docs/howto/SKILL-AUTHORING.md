# How to Create a New Skill

This guide walks through creating a new skill (slash command) for the Agentic-Claude library. Skills are reusable workflows invoked with `/skill-name` in any Claude Code session.

---

## Upstream reference

Our SKILL.md conventions follow Anthropic's official reference skills repository, [anthropics/skills](https://github.com/anthropics/skills), pinned to commit [`c30d329`](https://github.com/anthropics/skills/tree/c30d329f5814647c1e2f071020c1e8c1c9893ef1) (2026-06-07) for reproducibility. We use it **reference-only** — as the canonical SKILL.md style baseline. We do not install, copy, or republish it. When the upstream conventions evolve, re-pin a newer commit here.

Two further sources complement that baseline:

- **Normative spec** — the [official Claude Code Skills documentation](https://code.claude.com/docs/en/skills) is the authoritative reference for how Skills work (frontmatter, structure, discovery). The relationship: this doc is the **spec**; anthropics/skills are **worked examples** of it. It is Anthropic-owned and changes over time, so we link rather than copy its content.
- **Discovery index** — [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) is a community-curated index, **reference-only** for finding skills; it is not installed or vetted by us. Any individual skill picked from it needs its own license and provenance check before adoption.

### Alignment checklist

Self-check a new skill against the upstream conventions before submitting:

- [ ] YAML frontmatter has both required fields: `name` and `description`.
- [ ] `name` is lowercase with hyphens, unique, and matches the folder name exactly.
- [ ] `description` is third-person and states **what the skill does** *and* **when to use it** (explicit trigger phrases).
- [ ] `SKILL.md` itself is kept short — it is the entry point, not the whole manual.
- [ ] Substantial content (long references, scripts, datasets) is bundled as separate files in the skill folder and loaded **on demand** (progressive disclosure), not inlined.
- [ ] The body gives clear, repeatable instructions Claude follows when the skill is active.
- [ ] Examples / usage scenarios are included so the workflow is unambiguous.
- [ ] Any bundled scripts or resources are referenced by relative path from `SKILL.md`.

> Library-specific additions beyond the upstream baseline: our `allowed-tools` frontmatter (least-privilege), our step-numbered workflow structure, and the mandatory structured **Report** step (see below).

---

## Skills vs Agents — choose the right tool

| | Skill | Agent |
|-|-------|-------|
| Invocation | `/skill-name` in chat | Spawned by orchestrator |
| Memory | No (stateless per invocation) | Yes (`memory: project`) |
| Tool restriction | Enforced by `allowed-tools` | Enforced by `tools:` |
| Best for | Repeatable workflows | Long-running specialized roles |
| Context | Runs in current conversation | Runs in its own context |

**Create a skill** when the workflow is:
- Repeatable and well-defined (same steps every time)
- Short enough to run in a single conversation turn
- Not role-specific (any agent or the user can invoke it)

**Create an agent** when the work requires memory across sessions, has complex reasoning, or needs to be orchestrated alongside other agents.

---

## Step 1: Create the folder

```bash
mkdir skills/<skill-name>
# Skill names: lowercase, hyphenated (e.g., api-migrate, db-seed, lint-fix)
```

---

## Step 2: Write SKILL.md

Create `skills/<skill-name>/SKILL.md`. Same two-part structure: YAML frontmatter + markdown body.

### Required frontmatter fields

```yaml
---
name: <skill-name>           # Must match the folder name exactly
description: >
  One paragraph: what this skill does, what it produces, and when to use it.
  Include trigger phrases (e.g., "Use when the user says 'migrate', 'convert'...")
allowed-tools: Read, Grep    # Comma-separated. Principle of least privilege.
---
```

### Tool selection for skills

Use the minimal set of tools needed for the workflow:
- **Read-only analysis**: `Read, Grep, Glob, Bash`
- **Code modification**: `Read, Write, Edit, Bash, Grep, Glob`
- **Research**: `Read, WebSearch, WebFetch, Grep, Glob`
- **Task tracking**: add `TodoWrite` when the workflow has 5+ steps

---

## Step 3: Write the workflow body

Skills are step-by-step workflows. Each step should:
1. Have a clear action verb ("Read", "Analyze", "Create", "Run", "Report")
2. Include concrete commands or templates where useful
3. Produce a specific output that feeds the next step

### Recommended structure

```markdown
# /<skill-name> — <Short Title>

## Step 1: <Gather Context / Understand the Request>

<What to read or check before starting. Always include CLAUDE.md and team-findings.md reads.>

## Step 2: <Analyze / Plan>

<How to assess scope and create a task list.>

## Step 3: <Implement / Execute>

<The core work. Include code templates, command examples, or checklists.>

## Step 4: <Validate>

<How to verify the work is correct before reporting.>

## Step 5: <Report>

<Structured output format. Always use a consistent markdown report block.>
```

### Report format convention

Every skill must end with a structured report. Use this pattern:

```markdown
## Step N: Report

```
## <SkillName> Results: <scope>

### Summary
<2-3 sentence overview>

### <Primary Output>
<table or bullet list of main findings/changes>

### Next Steps
- [ ] <action item>
- [ ] <action item>
```
```

---

## Step 4: Reference patterns from existing skills

Before writing a new skill, check if existing ones solve a similar problem:

| Existing skill | Reuse when |
|---------------|------------|
| `/develop` | Feature implementation, bug fixes |
| `/review` | Code quality, security checks |
| `/test` | Test execution, coverage, mutation |
| `/deploy` | CI/CD, Docker, Azure, pipelines |
| `/document` | CLAUDE.md updates, ADRs, diagram sync |

If your skill extends an existing one (e.g., "like /review but only for API contracts"), consider adding an option to the existing skill instead of creating a new one.

---

## Step 5: Register in CLAUDE.md

Add to the Skill Inventory table in `CLAUDE.md`:

```markdown
| `<skill-name>` | `/<skill-name>` | <one-line description> |
```

Also add to the Repository Structure tree under `skills/`.

---

## Step 6: Run validation

```bash
python3 scripts/validate_agents.py
```

The validator checks that `name:` and `allowed-tools:` are present.

---

## Step 7: Update CHANGELOG.md

```markdown
- **`skills/<name>/SKILL.md`** — New skill: <one-line description>
```

---

## Checklist before submitting a PR

- [ ] `skills/<name>/SKILL.md` with `name:` and `allowed-tools:` frontmatter
- [ ] Workflow has at least 4 steps (gather context → analyze → execute → report)
- [ ] Report step uses structured markdown format
- [ ] `allowed-tools` follows principle of least privilege
- [ ] Added to `CLAUDE.md` Skill Inventory table
- [ ] CHANGELOG.md updated
- [ ] CI `validate.yml` passes
