---
name: feature-team
version: 1.1.0
description: Developer + Tester + Documentarian — implement a feature end-to-end.
---

# Feature Team

## Workspace Context

This team definition lives in the **AI Tools repo** (shared library). When executing, all work targets the **project repo** (the working directory). Memory paths (`.claude/memory/checkpoints/`, `.claude/memory/team-findings.md`, `.claude/memory/sessions/`) resolve under the project repo, not here.

## Composition

| Agent | Role in Team | Primary Responsibility |
|-------|-------------|----------------------|
| **developer** | Implementer | Write/modify production code |
| **tester** | Validator | Write and run tests |
| **documentarian** | Context keeper | Update docs after changes |

> **Architect (optional)** — Invoke as a prerequisite when the feature touches integration boundaries (APIC API definitions, ACE flows, MQ queues, inter-service contracts). Run architect first, pass findings to developer via `team-findings.md`. For pure in-app changes with no integration scope, skip architect.

## Workflow

```
0. Lead checks .claude/memory/checkpoints/active.md for interrupted workflow (recovery mode)
   If no active checkpoint: reads .claude/memory/sessions/ for prior context
1. PO/Lead defines the feature spec with acceptance criteria
   └─ If integration scope: Architect maps dependencies first → writes to team-findings.md
2. Developer implements the feature (reads team-findings.md for architect context)
3. Tester writes and runs tests against the implementation
4. Documentarian updates CLAUDE.md, relevant docs, and consolidates team-findings.md
5. Lead reviews all outputs and reports to PO
6. Lead writes session summary to .claude/memory/sessions/
```

## Task Assignment Pattern

When spawning this team, assign tasks as follows:

- **Developer**: "Implement <feature> in <module>. Acceptance criteria: <list>. Do not modify test files or docs."
- **Tester**: "Write and run tests for <feature> in <module>. Verify acceptance criteria: <list>. Report pass/fail."
- **Documentarian**: "After developer and tester complete, update CLAUDE.md and docs to reflect the new <feature>."

## File Boundaries

To avoid conflicts:
- Developer owns: `src/`, `lib/`, `features/`, `application/`
- Tester owns: `tests/`
- Documentarian owns: `CLAUDE.md`, `docs/`, `README.md`

No agent should modify files outside its boundary.

## Dependencies

```
Developer (1) → Tester (2) → Documentarian (3)
                     ↘ (parallel if no conflicts)
```

Tester waits for developer. Documentarian can start after developer finishes (reads code) and finishes after tester reports results.

## Team Memory

All agents write cross-team discoveries to `.claude/memory/team-findings.md`. The orchestrator reads this file before spawning agents and includes relevant context in task instructions.

At the end of the workflow, the documentarian consolidates team-findings.md entries into CLAUDE.md and removes stale entries.

## Coordination Protocol

### Context Budget
Each agent's response to the orchestrator must stay under **2000 characters** for status updates. Final deliverable reports may be longer but must use structured formats (tables, bullet points).

### Progress Checkpoints
The orchestrator must receive a status update after each agent completes its work:

```
| Agent | Task | Status | Summary |
|-------|------|--------|---------|
| Developer | Implement X | Done | Modified 3 files: a.py, b.py, c.py |
| Tester | Test X | In progress | 12/15 tests passing |
| Documentarian | Update docs | Pending | Waiting for tester |
```

### Parallel Execution Limits
- **Maximum 2 agents in parallel** to prevent context overflow
- The orchestrator must synthesize results from completed agents before spawning the next batch
- If total accumulated output exceeds 5 agent responses, pause and summarize before continuing

### Error Escalation
If any agent reports BLOCKED:
1. Orchestrator pauses other agents if they depend on the blocked task
2. Orchestrator presents options to the PO (human)
3. Work resumes only after PO decision

## Crash Recovery

### Checkpoint File
The team uses `.claude/memory/checkpoints/active.md` as a persistent crash-recovery log. All agents append their progress to this file in addition to reporting in-context.

### Workflow Start
The orchestrator creates the checkpoint file at workflow start:
1. Create `.claude/memory/checkpoints/` directory if it doesn't exist
2. Write the checkpoint header to `active.md` (team name, goal, timestamp, agents)
3. Append the PLAN entry with task breakdown

### Crash Detection
At the start of every session, before any work:
1. Check if `.claude/memory/checkpoints/active.md` exists
2. If yes: read the file, present recovery summary to PO, wait for decision (resume/restart/review)
3. If no: proceed normally

### Resume Protocol
When resuming from a crash:
1. Read checkpoint file to determine last-known state per agent
2. Verify on-disk artifacts match checkpoint claims (e.g., if developer DONE, check that files exist)
3. Append a RESUMED entry to the checkpoint file
4. Re-assign only incomplete tasks (skip DONE agents unless user requests re-validation)
5. Continue the normal workflow from the interruption point

### Cleanup
On successful workflow completion:
1. Read checkpoint file to inform the session summary
2. Write session summary to `.claude/memory/sessions/YYYY-MM-DD-<slug>.md`
3. Delete `.claude/memory/checkpoints/active.md`
