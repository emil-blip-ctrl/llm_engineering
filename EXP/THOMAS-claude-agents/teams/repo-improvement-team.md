---
name: repo-improvement-team
version: 1.0.0
description: Product-owner-assistant (lead) + Library-maintainer — the only team that may modify this library.
---

# Repo Improvement Team

The **only** team permitted to modify this library (the Agentic-Claude repo itself). It runs in
two phases: it **recommends** improvements to a human, and — only on approval — **applies** them,
refreshes the wiki, and hands the diff back for the human to commit.

## Workspace Context — IMPORTANT (inverted from other teams)

> Every **other** team treats the AI Tools repo as read-only and works in the consuming project.
> **This team is the exception:** the Agentic-Claude library repo **is** the working directory.
> Modification rights are confined to this team's **dedicated agent** (`library-maintainer`),
> which belongs only here. The shared project agents keep their
> "never modify the AI Tools repo" guard untouched. Skills are shared freely across all agents.

Because changes touch shared definitions every project depends on, this team **never commits or
publishes autonomously** — a human approves recommendations and is the only committer.

## Composition

| Agent | Belongs to | Role in Team | Primary Responsibility |
|-------|-----------|--------------|----------------------|
| **product-owner-assistant** | shared (orchestrator) | Lead | Frame the goal, run the phases, gather the human's approval. Edits nothing. |
| **library-maintainer** | **this team only** | Definitions, docs & tooling | Edit agent/skill/team Markdown, keep CLAUDE.md inventory in sync, change `templates/install.ps1`, `scripts/`, `.claude/hooks/`, run `/publish-confluence` |

The PO orchestrates (as it does for every team) without editing files, so it needs no special
rights. The dedicated agent is the only one allowed to write to this repo.

## Workflow

```
0. Lead checks .claude/memory/checkpoints/active.md for an interrupted workflow (recovery mode)

=== Phase A — RECOMMEND (no edits) ===
1. Lead frames the goal (or "general review")
2. library-maintainer analyses definitions + docs + team-findings.md + recent sessions,
   and scripts/installer/hooks (if in scope)
3. Lead synthesises a RECOMMENDATION REPORT for the human:
   proposed change · rationale · evidence (file:line / finding) · impact · priority
4. Human selects which recommendations to apply  ◄── approval gate

=== Phase B — APPLY (approved items only) ===
5. library-maintainer edits definitions/docs and tooling
6. library-maintainer updates CLAUDE.md (Repository Structure + Agent/Skill/Team tables) to match
7. library-maintainer validates (installer/publish script run; frontmatter well-formed)
8. library-maintainer runs /publish-confluence to refresh the read-only wiki tree
9. Lead presents the full diff + wiki changes; HUMAN commits & pushes (the commit hook
   refuses the commit if the inventory still drifts)
10. Lead writes a session summary to .claude/memory/sessions/
```

## Task Assignment Pattern

- **library-maintainer (recommend)**: "Review the library (definitions, docs, installer/scripts/hooks) against team-findings.md and recent sessions. Propose prioritised improvements — no edits."
- **library-maintainer (apply)**: "Apply approved items #… Update the CLAUDE.md inventory to match. Validate by running the tooling. Then run /publish-confluence. Do not commit."

## File Boundaries

- library-maintainer owns: `agents/`, `skills/`, `teams/`, `docs/`, `CLAUDE.md`, `README.md`, `templates/install.ps1`, `scripts/`, `.claude/hooks/`, `.claude/settings.json`
- No other agent or team may modify this repo.

## Approval Gate (mandatory)

This team **must not commit or publish without explicit human approval.** Phase A is read-only;
Phase B runs only on approved items; the human is the sole committer. The
`.claude/hooks/pre-commit-guard.ps1` hook backstops this by blocking a `git commit` whose
CLAUDE.md inventory is out of sync. See [`CLAUDE.md`](../CLAUDE.md) → "Self-Improvement Workflow".

## Team Memory

All agents append cross-cutting discoveries to `.claude/memory/team-findings.md`; the
library-maintainer consolidates them into `CLAUDE.md` during Phase B.

## Coordination Protocol

- **Context budget:** status updates under 2000 characters; tables/bullets; reference `path:line`, never paste files.
- **Max 2 agents in parallel;** the Lead synthesises before the next batch.
- **Error escalation:** any `BLOCKED` pauses dependent work; the Lead presents options to the human.

## Crash Recovery

Same protocol as other teams: the Lead creates `.claude/memory/checkpoints/active.md` at start,
agents append progress, it is read on session start to detect interruptions, and it is deleted on
successful completion after the session summary is written.
