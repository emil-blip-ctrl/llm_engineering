---
name: release-team
version: 1.1.0
description: DevOps + Tester + Documentarian — prepare and validate a release.
---

# Release Team

## Workspace Context

This team definition lives in the **AI Tools repo** (shared library). When executing, all work targets the **project repo** (the working directory). Memory paths (`.claude/memory/checkpoints/`, `.claude/memory/team-findings.md`, `.claude/memory/sessions/`) resolve under the project repo, not here.

## Composition

| Agent | Role in Team | Primary Responsibility |
|-------|-------------|----------------------|
| **devops** | Pipeline builder | CI/CD, Docker, deployment configs |
| **tester** | Quality gate | Run full test suite, validate readiness |
| **documentarian** | Release notes | Update operations docs, changelog |

> **Architect (optional)** — Invoke before the release workflow when the release includes API contract changes, new integration points, or APIC API version bumps. Architect documents breaking changes in `docs/architecture/` so DevOps and Documentarian have accurate context. Skip for patch releases with no integration scope.

## Workflow

```
0. Lead checks .claude/memory/checkpoints/active.md for interrupted workflow (recovery mode)
   If no active checkpoint: reads .claude/memory/sessions/ for prior context
1. PO/Lead decides to prepare a release
2. Tester runs the full test suite and reports status
3. DevOps prepares/updates deployment pipeline and configs
4. Tester validates the pipeline (dry run if possible)
5. Documentarian updates operations docs, changelog, and consolidates team-findings.md
6. Lead reviews all outputs and reports readiness to PO
7. Lead writes session summary to .claude/memory/sessions/
```

## Task Assignment Pattern

- **Tester**: "Run the full test suite. Report: total, passed, failed, coverage. Flag any regressions."
- **DevOps**: "Prepare deployment for <environment>. Ensure CI pipeline is green. Update Docker/Azure configs as needed."
- **Documentarian**: "Update operations docs, changelog, and deployment instructions for the release."

## File Boundaries

- DevOps owns: `.github/workflows/`, `Dockerfile*`, `docker-compose*`, `infra/`, `bicep/`
- Tester owns: `tests/` (read-only during release — no new tests)
- Documentarian owns: `docs/operations/`, `CHANGELOG.md`, `CLAUDE.md`

## Dependencies

```
Tester (1) ──→ DevOps (2) ──→ Documentarian (3)
   ↓                              ↑
   └──────── (results feed) ──────┘
```

Tester runs first to confirm code is release-ready. DevOps proceeds only if tests pass. Documentarian captures the release details.

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
| Tester | Full test suite | Done | 142 passed, 0 failed, 87% coverage |
| DevOps | Pipeline update | In progress | CI green, deploying to staging |
| Documentarian | Release notes | Pending | Waiting for DevOps |
```

### Parallel Execution Limits
- **Maximum 2 agents in parallel** to prevent context overflow
- This team is sequential by design (tester → devops → documentarian), so parallel execution is rare
- If an agent's output is unexpectedly large, the orchestrator must summarize before passing to the next agent

### Error Escalation
If tests fail or pipeline breaks:
1. Orchestrator halts the release workflow
2. Reports failure details to PO with options: fix and retry, or abort release
3. Does NOT proceed to next agent until issue is resolved

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
2. Verify on-disk artifacts match checkpoint claims (e.g., if tester DONE, check test results)
3. Append a RESUMED entry to the checkpoint file
4. Re-assign only incomplete tasks (skip DONE agents unless user requests re-validation)
5. Continue the normal workflow from the interruption point

### Cleanup
On successful workflow completion:
1. Read checkpoint file to inform the session summary
2. Write session summary to `.claude/memory/sessions/YYYY-MM-DD-<slug>.md`
3. Delete `.claude/memory/checkpoints/active.md`
