# How to Create a New Team

Teams are composition blueprints — they describe which agents to spawn together for a specific workflow, in what order, with what boundaries. They live in `teams/` and are read by the orchestrator (product-owner-assistant) at runtime.

---

## When to create a new team

Create a team when you have a **recurring multi-agent workflow** that:
- Uses 2+ agents together in a consistent sequence
- Has clear file ownership boundaries (no agents modifying the same files)
- Is triggered often enough to warrant documentation

**Don't create a team** for one-off workflows or for workflows that only use a single agent.

---

## Step 1: Create the file

```bash
# Team name: lowercase hyphenated noun phrase describing the goal
# e.g., data-migration-team, api-review-team, incident-team
touch teams/<team-name>.md
```

---

## Step 2: Write the team file

Every team file follows this structure:

```markdown
# <Team Name>

## Workspace Context

This team definition lives in the **AI Tools repo** (shared library). When executing,
all work targets the **project repo** (the working directory). Memory paths
(`.claude/memory/checkpoints/`, `.claude/memory/team-findings.md`,
`.claude/memory/sessions/`) resolve under the project repo, not here.

## Composition

| Agent | Role in Team | Primary Responsibility |
|-------|-------------|----------------------|
| **<agent>** | <role label> | <one-line responsibility> |

> **<Agent> (optional)** — When to include, when to skip.

## Workflow

```
0. Lead checks .claude/memory/checkpoints/active.md (recovery mode)
1. <First step>
2. <Second step>
...
```

## Task Assignment Pattern

- **<Agent>**: "Instruction template for this agent."

## File Boundaries

| Agent | Owns | Read-Only |
|-------|------|-----------|
| <Agent> | `path/to/owned/` | Everything else |

## Dependencies

```
Agent1 (1) → Agent2 (2) → Agent3 (3)
```

## Team Memory

All agents write cross-team discoveries to `.claude/memory/team-findings.md`.

## Coordination Protocol

### Context Budget
Each agent's response must stay under **2000 characters** for status updates.

### Parallel Execution Limits
- **Maximum 2 agents in parallel**
- Synthesize before spawning the next batch

### Error Escalation
If any agent reports BLOCKED:
1. Orchestrator pauses dependent agents
2. Presents options to the PO
3. Work resumes only after PO decision

## Crash Recovery

### Checkpoint File
Uses `.claude/memory/checkpoints/active.md` (append-only).

### Workflow Start
1. Create `.claude/memory/checkpoints/` if it doesn't exist
2. Write checkpoint header (team name, goal, timestamp, agents)
3. Append PLAN entry

### Crash Detection
At session start: check if `active.md` exists → present recovery summary → wait for PO decision.

### Resume Protocol
1. Read checkpoint for last-known state per agent
2. Verify on-disk artifacts match claims
3. Append RESUMED entry
4. Re-assign only incomplete tasks

### Cleanup
On success: write session summary → delete `active.md`.
```

---

## Step 3: Key decisions

### Sequential vs parallel

Default to **sequential** unless you are certain two agents never touch the same files.

```
# Sequential (safe default)
Agent1 → Agent2 → Agent3

# Parallel when files are completely separate
Agent1 (src/) ─┐
               ├─→ Agent3 (tests/)
Agent2 (ci/)  ─┘
```

**Maximum 2 agents in parallel** — more than that risks context window overflow.

### File boundaries

Be explicit. Ambiguous file ownership causes agents to overwrite each other's work.

| ✅ Clear | ❌ Ambiguous |
|---------|------------|
| Developer owns `src/`, tester owns `tests/` | "Developer and tester both work on the feature" |
| DevOps owns `.github/workflows/` | "DevOps can modify anything infrastructure-related" |

### Crash recovery

All teams must include the crash recovery section. Copy it from an existing team (e.g., `feature-team.md`) — the protocol is identical for every team.

---

## Step 4: Register in CLAUDE.md

Add to the Team Inventory table:

```markdown
| `<team-name>` | <agent list> | <use case> |
```

Also add to the Repository Structure tree under `teams/`.

---

## Step 5: Register in README.md

Add a row to the Teams table.

---

## Checklist before submitting a PR

- [ ] `teams/<name>.md` created with all required sections
- [ ] Composition table lists all agents with roles
- [ ] Workflow steps are numbered and include the checkpoint check at step 0
- [ ] File boundaries table has no overlaps
- [ ] Crash recovery section included (copy from existing team)
- [ ] Parallel execution limit documented (max 2)
- [ ] Registered in `CLAUDE.md` Team Inventory table
- [ ] Registered in `README.md` Teams table
- [ ] CHANGELOG.md updated
