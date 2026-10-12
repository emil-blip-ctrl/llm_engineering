# How to Create a New Agent

This guide walks through creating a new agent for the Agentic-Claude library. Follow every step — the CI validation workflow will reject agents missing required fields.

---

## When to create a new agent

Create a new agent when:
- A role requires a **distinct tool set** not covered by existing agents (e.g., a security auditor who only reads, or a data analyst who runs notebooks)
- A role has **domain expertise** that should be isolated (e.g., a Salesforce specialist)
- You need strict **file boundary enforcement** (e.g., an agent that must never touch production code)

Do NOT create a new agent for:
- A project-specific variant of an existing agent (customize via CLAUDE.md project notes instead)
- A one-off task (use a skill instead)
- Adding a tool to an existing agent (just edit the existing AGENT.md)

---

## Step 1: Create the folder

```bash
mkdir agents/<agent-name>
# Agent names: lowercase, hyphenated (e.g., security-auditor, data-analyst)
```

---

## Step 2: Write AGENT.md

Create `agents/<agent-name>/AGENT.md`. The file has two parts: a YAML frontmatter block and a markdown body.

### Required frontmatter fields

```yaml
---
name: <agent-name>           # Must match the folder name exactly
description: >
  One paragraph describing: what this agent does, what it does NOT do,
  and when to delegate to it. Start with the verb (e.g. "Analyzes...", "Builds...")
model: claude-opus-4-8       # Use latest Opus for complex reasoning agents
                             # Use claude-sonnet-4-6 for lighter read/write agents
tools: Read, Write, Edit     # Comma-separated. See tool reference below.
memory: project              # Always "project" — never "user"
---
```

### Model selection guide

| Model | Use when |
|-------|----------|
| `claude-opus-4-8` | Complex reasoning, multi-step analysis, code writing |
| `claude-sonnet-4-6` | Documentation, summarization, light editing |
| `claude-haiku-4-5-20251001` | Simple lookups, classification, high-volume tasks |

### Tool reference

| Tool | Use for |
|------|---------|
| `Read` | Reading files |
| `Write` | Creating new files |
| `Edit` | Modifying existing files |
| `Bash` | Running shell commands |
| `Grep` | Searching file contents |
| `Glob` | Finding files by pattern |
| `Task` | Spawning subtasks |
| `WebSearch` | Searching the web |
| `WebFetch` | Fetching URLs |
| `TodoWrite` | Managing task lists |
| `AskUserQuestion` | Asking the human for input |
| `NotebookEdit` | Editing Jupyter notebooks |

**Principle of least privilege**: only include tools the agent genuinely needs for its role.

---

## Step 3: Write the markdown body

Use this structure (copy-paste and fill in):

```markdown
# <AgentName> Agent

You are the <AgentName> agent. You <one sentence core identity>.

## Core Identity

<2-3 sentences: what you do, what you explicitly do NOT do, how you report results>

## Memory Management

At the start of each session, review your MEMORY.md for previously discovered patterns.

**Write to memory when you discover:**
- <domain-specific pattern worth remembering>
- <gotcha that caused issues>

**Write to team-findings.md** (`.claude/memory/team-findings.md`) when you discover
something other agents need to know.

**Do not write to memory:**
- Transient task progress (use TodoWrite instead)
- Full file contents or raw command output
- Information already in CLAUDE.md

**Format**: Keep entries concise (1-2 lines). Date-stamp new entries.

## Workspace Orientation

You may be running in a multi-root VS Code workspace with two repos:

| Folder | Purpose | You should... |
|--------|---------|---------------|
| **Project repo** | The codebase you're working on | Focus all work here |
| **AI Tools repo** | Shared agent/skill library | Read-only reference only |

All memory paths resolve under the project repo's `.claude/` directory.

## Work Instructions — <Primary Domain>

<Step-by-step instructions for how to do the work. Be specific. Include examples.>

## Work Instructions — Progress Reporting

### Checkpoint Protocol
1. **Start**: "Starting <task>. Plan: <1-2 sentence summary>."
2. **After each major action**: "<Action> complete — <one-line result>."
3. **On blockers**: "BLOCKED: <description>. Need: <what would unblock>."
4. **Completion**: Structured report with all findings/changes.

### Heartbeat Rule
Send an intermediate status update after every 3+ tool calls. Do not wait until done.

### Crash-Recovery Checkpoints
**File**: `.claude/memory/checkpoints/active.md` (append-only)

Append at START, PROGRESS, BLOCKED, and DONE:
```
### [HH:MM:SS] <agent-name> | <STATUS>
<1-3 line summary>
```

## Work Instructions — Output Discipline

- Never dump full file contents — summarize and reference file:line
- Keep status updates under 2000 characters
- Use tables and bullet points for findings
- Report outcomes (pass/fail, key numbers), not raw command output

## Constraints

- Do NOT <explicit prohibition 1>
- Do NOT <explicit prohibition 2>
- Do NOT commit code — report changes and let the user or orchestrator commit
```

---

## Step 4: Register in CLAUDE.md

Add the new agent to the Agent Inventory table in `CLAUDE.md`:

```markdown
| `<agent-name>` | <model-short> | project | <tools list> | <one-line description> |
```

Also add it to the Repository Structure tree under `agents/`.

---

## Step 5: Add to teams (if applicable)

If the new agent participates in team workflows, update the relevant team files in `teams/`:
- Add to composition table
- Add to workflow steps
- Add file boundaries
- Add to parallel execution diagram

---

## Step 6: Run validation

```bash
# Local validation
python3 scripts/validate_agents.py

# Or let CI catch it on push
git push origin feature/<branch>
```

---

## Step 7: Update CHANGELOG.md

Add an entry under the current version:
```markdown
- **`agents/<name>/AGENT.md`** — New agent: <one-line description>
```

---

## Checklist before submitting a PR

- [ ] `agents/<name>/AGENT.md` created with all required frontmatter fields
- [ ] `model:` uses a known-latest model ID (run `validate_agents.py` to check)
- [ ] `memory: project` (not `user`)
- [ ] Markdown body has all required sections: Core Identity, Memory Management, Workspace Orientation, Work Instructions, Progress Reporting, Output Discipline, Constraints
- [ ] Agent added to `CLAUDE.md` Agent Inventory table
- [ ] Agent added to relevant team files if applicable
- [ ] CHANGELOG.md updated
- [ ] CI `validate.yml` passes
