---
name: full-team
version: 1.1.0
description: All agents — major features, bootstrapping, migrations.
---

# Full Team

## Workspace Context

This team definition lives in the **AI Tools repo** (shared library). When executing, all work targets the **project repo** (the working directory). Memory paths (`.claude/memory/checkpoints/`, `.claude/memory/team-findings.md`, `.claude/memory/sessions/`) resolve under the project repo, not here.

## Composition

| Agent | Role in Team | Primary Responsibility |
|-------|-------------|----------------------|
| **product-owner-assistant** | Lead / Orchestrator | Coordination, prioritization, quality gates |
| **architect** | Integration Analyst | Architecture analysis, dependency mapping, ADRs |
| **developer** | Implementer | Write/modify production code |
| **tester** | Validator | Write and run tests |
| **devops** | Infrastructure | CI/CD, Docker, Azure, deployments |
| **documentarian** | Context keeper | Documentation, CLAUDE.md, ADRs |

## When to Use

Use the full team for:
- Major feature implementations requiring code + tests + infra + docs
- Project bootstrapping (new repo setup)
- Migration or refactoring efforts
- Release cycles that include new features

## Workflow

```
0. PO Assistant checks .claude/memory/checkpoints/active.md for interrupted workflow (recovery mode)
   If no active checkpoint: reads .claude/memory/sessions/ for prior context
1. PO Assistant receives the request from PO (human)
2. PO Assistant breaks it into stories and assigns agents
3. Architect maps integration dependencies and documents patterns (if integration scope)
4. Developer implements features (uses architect findings from team-findings.md)
5. Tester validates implementation
6. DevOps updates pipeline if needed
7. Documentarian updates all affected docs and consolidates team-findings.md
8. PO Assistant runs quality gates and reports to PO
9. PO Assistant writes session summary to .claude/memory/sessions/
```

## Task Assignment Pattern

PO Assistant creates tasks with clear dependencies:

```
Task 0 (Architect): Map integration dependencies — no deps (skip if no integration scope)
Task 1 (Developer): Implement <feature> — depends on Task 0 findings
Task 2 (Tester): Test <feature> — depends on Task 1
Task 3 (DevOps): Update CI for <feature> — depends on Task 1
Task 4 (Documentarian): Update docs — depends on Task 1, 2, 3
Task 5 (PO Assistant): Quality gate review — depends on all
```

## File Boundaries

| Agent | Owns | Read-Only |
|-------|------|-----------|
| Architect | `docs/architecture/`, `docs/adr/` | Everything (read all sources) |
| Developer | `src/`, `lib/`, `features/`, `application/` | `tests/`, `docs/` |
| Tester | `tests/` | `src/`, `lib/`, `features/` |
| DevOps | `.github/`, `Dockerfile*`, `infra/`, `bicep/` | Everything else |
| Documentarian | `CLAUDE.md`, `docs/`, `README.md` | Everything else |
| PO Assistant | (none — read only) | Everything |

## Parallel Execution Opportunities

These agents can work simultaneously when their tasks are independent:

```
Architect (analysis) ──→ Developer (feature A) ─┐
                                                  ├─→ Tester (all) → Documentarian
                         DevOps (pipeline)       ─┘
```

- Architect runs first (sequential) to feed findings into team-findings.md
- Developer and DevOps can work in parallel (different files), both informed by Architect
- Tester must wait for Developer
- Documentarian waits for all others

## Conflict Resolution

If two agents need to modify the same file:
1. PO Assistant detects the conflict
2. Assigns file ownership to one agent
3. Second agent waits or works on different files
4. PO Assistant merges outputs if needed

## Team Memory

All agents write cross-team discoveries to `.claude/memory/team-findings.md`. The PO Assistant reads this file before spawning agents and includes relevant context in task instructions.

At the end of the workflow, the PO Assistant instructs the documentarian to consolidate team-findings.md entries into CLAUDE.md and remove stale entries.

## Coordination Protocol

### Context Budget
Each agent's response to the orchestrator must stay under **2000 characters** for status updates. Final deliverable reports may be longer but must use structured formats (tables, bullet points).

### Progress Checkpoints
PO Assistant maintains a live status table and updates it after every agent response:

```
| Agent | Task | Status | Summary |
|-------|------|--------|---------|
| Developer | Implement feature | Done | Modified 3 files |
| Tester | Write + run tests | In progress | 8/10 passing |
| DevOps | Update pipeline | Done | Added new step to ci.yml |
| Documentarian | Update docs | Pending | Waiting for tester |
| PO Assistant | Quality gate | Pending | Waiting for all |
```

### Parallel Execution Limits — CRITICAL
- **Maximum 2 agents in parallel at any time** to prevent context window overflow
- Recommended pattern: Developer + DevOps in parallel (different files), then Tester, then Documentarian
- **Never spawn exploration agents in parallel** — explore sequentially to control output volume
- PO Assistant must synthesize results from completed agents before spawning the next batch
- If total accumulated output exceeds 5 agent responses in a single phase, PO Assistant must pause, summarize findings to the PO, and get approval before continuing

### Phased Execution
For large tasks, break work into phases:
```
Phase 1: Exploration — PO Assistant scopes the work (1-2 targeted agents, sequential)
Phase 2: Planning — PO Assistant presents plan to PO for approval
Phase 3: Implementation — Developer + DevOps in parallel (max 2)
Phase 4: Validation — Tester runs tests
Phase 5: Documentation — Documentarian updates docs
Phase 6: Quality Gate — PO Assistant reviews all outputs
```

### Error Escalation
If any agent reports BLOCKED:
1. PO Assistant pauses dependent agents
2. PO Assistant presents options to PO (human) with context
3. Work resumes only after PO decision
4. PO Assistant never guesses or works around blockers silently

## Crash Recovery

### Checkpoint File
The team uses `.claude/memory/checkpoints/active.md` as a persistent crash-recovery log. All agents append their progress to this file in addition to reporting in-context.

### Workflow Start
PO Assistant creates the checkpoint file at workflow start:
1. Create `.claude/memory/checkpoints/` directory if it doesn't exist
2. Write the checkpoint header to `active.md` (team name, goal, timestamp, agents)
3. Append the PLAN entry with task breakdown

### Crash Detection
At the start of every session, before any work:
1. PO Assistant checks if `.claude/memory/checkpoints/active.md` exists
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
1. PO Assistant reads checkpoint file to inform the session summary
2. Write session summary to `.claude/memory/sessions/YYYY-MM-DD-<slug>.md`
3. Delete `.claude/memory/checkpoints/active.md`
