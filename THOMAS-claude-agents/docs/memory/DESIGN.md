# Memory Architecture — Design Document

## Status: Implemented (v1.1+)

## Context

This document evaluates the 5-layer memory architecture (working, episodic, semantic, procedural, hierarchical) against what Claude Code actually provides, identifies what our agent library gets right and wrong today, and proposes concrete improvements.

Reference: "Top 5 Agent Memory Architectures You Must Know in 2026" (Brij Kishore Pandey, @brijpandeyji)

---

## Part 1: Critical Analysis of the Current Setup

### What `memory: user` Actually Is

Every agent in the library has `memory: user`. Here's what that means concretely:

- It gives the agent a **directory of markdown files** at `~/.claude/agent-memory/<agent-name>/`
- The first 200 lines (or 25KB) of `MEMORY.md` are injected into the agent's system prompt at startup
- The agent can create additional topic files (e.g., `python-patterns.md`) in the same directory
- The agent uses Read/Write/Edit tools to manage these files — nothing is automatic

**What it is NOT:**
- Not a vector store
- Not embeddings
- Not key-value pairs
- Not automatic — the agent must explicitly decide to write

### Problem 1: No Memory Instructions

None of our AGENT.md files tell the agents **when or what to write to memory**. The `memory: user` setting is enabled, but there are no instructions in the agent body text like "Update your memory when you discover patterns" or "Check your memory before starting work." This means **agents almost certainly never write to memory** — the feature is enabled but unused.

### Problem 2: Wrong Memory Scope

All agents use `memory: user`, which means memory lives at `~/.claude/agent-memory/` (user-global, across all projects). For a shared library installed into multiple projects, this causes **cross-project contamination**:

- The developer agent learns "this codebase uses factory pattern for services" in CMDBtoArchimate
- That knowledge gets injected into every future session, including unrelated projects
- The agent may apply CMDBtoArchimate conventions to a Node.js project

The correct scope depends on the type of knowledge:

| Knowledge Type | Right Scope | Example |
|----------------|-------------|---------|
| Domain expertise (SOLID, ISTQB) | `user` | "Prefer composition over inheritance" |
| Project conventions | `project` | "This codebase uses ChromaDB for persistence" |
| Personal preferences | `user` | "User prefers concise responses" |
| Codebase-specific gotchas | `project` | "The excel-import feature needs the fixture CSV" |

Most agent knowledge is project-specific, not universal. **The default should be `project`, not `user`.**

### Problem 3: Memory Isolation Between Agents

Agent memory is **completely siloed**. Each agent has its own directory:

```
~/.claude/agent-memory/developer/MEMORY.md     # developer sees only this
~/.claude/agent-memory/tester/MEMORY.md        # tester sees only this
~/.claude/agent-memory/documentarian/MEMORY.md # documentarian sees only this
```

The developer discovers "the shared kernel has a breaking change in the vector_store API." The tester — working on the same feature team — has no idea. The product-owner-assistant, who is supposed to orchestrate, cannot read any agent's memory.

This directly contradicts our team model. The feature-team.md says agents collaborate, but they can't share what they've learned.

### Problem 4: CLAUDE.md Is Manually Maintained Semantic Memory

CLAUDE.md is the project's semantic memory — distilled facts about architecture, conventions, and gotchas. The documentarian agent is responsible for keeping it current. But:

- Updates only happen when someone explicitly runs `/document`
- No trigger after a developer session that discovers a new pattern
- No mechanism for agents to flag "this should be in CLAUDE.md"
- Facts accumulate in agent memory but never consolidate into CLAUDE.md

This is the infographic's "unsolved consolidation problem" — episodes don't become facts unless a human intervenes.

---

## Part 2: Is ChromaDB Semantic Memory?

The CMDBtoArchimate project uses ChromaDB with 10 collections (~500+ entities). The question: should we use ChromaDB as a semantic memory store for agents?

**The honest answer: No.**

Here's why:

1. **ChromaDB stores application domain data, not agent memory.** The `apis` collection contains REST API metadata from IBM API Connect. The `ace_applications` collection contains ACE integration app definitions. This is the project's *data*, not knowledge *about* the project. Confusing the two conflates the application layer with the meta-cognitive layer.

2. **It couples the agent library to a specific technology.** The Claude Agents library is meant to be project-agnostic — it works with Python projects, Node projects, anything. Adding ChromaDB as a memory dependency means every consuming project needs ChromaDB installed, which defeats the "agents are roles, not projects" design principle.

3. **Vector search is overkill at this scale.** Agent memory contains dozens of patterns per project. A markdown file with 50-100 lines is more efficient than embedding, storing, and retrieving from a vector DB. The retrieval problem doesn't exist when the entire memory fits in a system prompt (200 lines / 25KB).

4. **Claude Code agents can't query ChromaDB directly.** There's no built-in ChromaDB tool. The agent would need to run a Python script (`python query_memory.py "what patterns did I learn?"`) via Bash, parse the output, and use it. This is fragile and adds latency to every agent startup.

**Where ChromaDB *could* add value (future, not now):** If the agent library scales to hundreds of projects with thousands of session logs, and you need similarity-based retrieval of past episodes ("find sessions where we dealt with ESQL parsing bugs"), then a vector store becomes justified. At that point, build it as an optional MCP server, not a hard dependency.

**For now, markdown files are the right storage layer.** They're human-readable, version-controllable, work on every project, and fit within Claude Code's native file tools.

---

## Part 3: Mapping to the 5-Layer Model

### Layer 1: Working Memory (Context Window)

**Infographic**: FIFO sliding window, oldest tokens dropped.
**Our setup**: Output discipline (<2000 chars), parallel limits (max 2 agents), synthesis checkpoints.
**Claude Code**: Auto-compaction at ~95% capacity. CLAUDE.md survives compaction (re-read from disk).

**Assessment: Well managed, minor improvements possible.**

Our output discipline is the right approach — preventing context overflow rather than recovering from it. The compaction mechanism is a safety net, not a strategy.

**Gap**: No agent instructions to "check your memory after compaction" to recover lost details. Post-compaction, agents should re-read their MEMORY.md to restore context.

### Layer 2: Episodic Memory (What Happened)

**Infographic**: Past interactions embedded in a vector store, retrieved by similarity.
**Our setup**: `memory: user` on all agents (but unused — no write instructions).
**Claude Code**: Auto memory for the main session (`~/.claude/projects/<project>/memory/MEMORY.md`). Subagent memory at `~/.claude/agent-memory/<name>/`.

**Assessment: Enabled but broken.** The infrastructure exists. Nobody writes to it.

**What's needed**:
- Explicit memory instructions in each AGENT.md
- Session handoff protocol (what to write at end of significant sessions)
- No vector store needed — file-based is sufficient at this scale

### Layer 3: Semantic Memory (What We Know to Be True)

**Infographic**: Entity graph, distilled facts, not raw history.
**Our setup**: CLAUDE.md (human-maintained), ADRs (human-initiated), ChromaDB (application data, not agent memory).
**Claude Code**: CLAUDE.md loaded every session. Agent MEMORY.md loaded at agent startup.

**Assessment: Strong foundation, weak maintenance.** CLAUDE.md is high-quality semantic memory when up to date. The problem is consolidation — episodic knowledge (session discoveries) rarely becomes semantic knowledge (CLAUDE.md facts).

**What's needed**:
- A consolidation trigger: "after completing a feature team workflow, the documentarian reviews agent memories and updates CLAUDE.md"
- Agent memory files that distinguish facts from episodes
- A `lessons.md` or `conventions.md` per-project that captures cross-session patterns

### Layer 4: Procedural Memory (How to Do It)

**Infographic**: Skill library, learned workflows, promoted from successful runs.
**Our setup**: `skills/` folder with 6 static workflows.

**Assessment: Strong but static.** The skills are well-defined procedural memory. However, they never evolve based on usage. A skill that fails repeatedly doesn't get updated. A successful ad-hoc workflow doesn't get promoted to a skill.

**What's needed**:
- Agent memory instructions to record "this approach worked/didn't work" after skill execution
- A periodic review process: "are skills still accurate? do we need new ones?"
- This is a human-in-the-loop process, not automation — skills should be curated, not auto-generated

### Layer 5: Hierarchical Memory (Hot/Warm/Cold)

**Infographic**: MemGPT-style paging between context window, fast store, and deep storage.
**Our setup**: Not present. Only the context window (hot) and CLAUDE.md (re-loaded after compaction).

**Assessment: Not needed yet.** Hierarchical memory solves the problem of agents running for months with unbounded memory. Our agents run for minutes to hours within a single session. The context window + compaction + MEMORY.md is sufficient. If sessions routinely hit compaction limits across multi-day workflows, revisit this.

---

## Part 4: Proposed Changes

### Principle: Minimum viable memory

Add only what directly solves the three real problems:
1. Agents don't write to memory (wasted feature)
2. Memory scope causes cross-project contamination
3. Agent memories are siloed from each other

Don't build: vector stores, hierarchical paging, auto-consolidation, or anything that requires infrastructure beyond files.

### Change 1: Fix Memory Scope

Switch most agents from `user` to `project` scope. Keep `user` only for universal domain expertise.

| Agent | Current | Proposed | Rationale |
|-------|---------|----------|-----------|
| `developer` | `user` | `project` | Code patterns are project-specific |
| `tester` | `user` | `project` | Test conventions are project-specific |
| `devops` | `user` | `project` | Pipeline configs are project-specific |
| `documentarian` | `user` | `project` | Documentation is project-specific by definition |
| `product-owner-assistant` | `user` | `project` | Backlog and priorities are project-specific |

**Trade-off**: Agents lose cross-project learning (e.g., "this user always prefers pytest parametrize"). This is acceptable — cross-project contamination is worse than cold starts.

**Alternative**: Use `project` as default but add a `user`-scoped "meta-agent" memory for universal preferences. Deferred until there's evidence of need.

### Change 2: Add Memory Instructions to All Agents

Add a **Memory Management** section to each AGENT.md body that tells the agent:
- **When to read**: At session start, check MEMORY.md for context
- **When to write**: After discovering patterns, conventions, or gotchas
- **What to write**: Distilled facts, not raw session logs
- **What NOT to write**: Transient task details, file contents, temporary state

Template for all agents:

```markdown
### Memory Management
At the start of each session, review your MEMORY.md for previously discovered patterns.

**Write to memory when you discover:**
- Project conventions not documented in CLAUDE.md
- Gotchas that caused errors or wasted time
- Patterns that worked well and should be repeated
- Dependencies or relationships between components

**Do not write to memory:**
- Transient task progress (use TodoWrite instead)
- Full file contents or command output
- Information already in CLAUDE.md (avoid duplication)

**Format**: Keep entries concise (1-2 lines each), grouped by topic. Date-stamp new entries.
```

Each agent gets a domain-specific version:
- **Developer**: code patterns, architecture quirks, dependency gotchas
- **Tester**: test infrastructure notes, fixture requirements, flaky test patterns
- **DevOps**: pipeline configurations, environment specifics, deployment gotchas
- **Documentarian**: documentation gaps found, style preferences observed
- **Product-owner-assistant**: stakeholder preferences, recurring blockers, team velocity patterns

### Change 3: Shared Team Memory via Conventions

Since Claude Code doesn't support cross-agent memory access, use a **file-based convention** for team knowledge sharing.

**Mechanism**: The product-owner-assistant (orchestrator) reads from a shared project file that all agents contribute to.

```
.claude/memory/team-findings.md    # project-scoped, git-tracked
```

**Protocol**:
1. When an agent discovers something team-relevant, it appends to `team-findings.md` (one-liner + file:line reference)
2. The product-owner-assistant reads `team-findings.md` before spawning agents
3. The documentarian consolidates `team-findings.md` into CLAUDE.md during `/document` runs
4. After consolidation, stale entries are removed from `team-findings.md`

This is a lightweight replacement for cross-agent memory sharing. It costs one file read per orchestration cycle.

**Model allocation**: All agents can Write to this file. Only the documentarian (sonnet) consolidates — this is a summarization task, not a reasoning task.

### Change 4: Session Handoff Protocol

Add instructions to the product-owner-assistant for writing a session summary when significant work is completed.

**Location**: `.claude/memory/sessions/` (project-scoped, not git-tracked)

**Template**:
```markdown
## Session: 2026-05-26 — [brief description]
### Completed
- [what was done, with file:line references]
### Decisions Made
- [architectural choices, trade-offs accepted]
### Open Items
- [what's left to do, blockers encountered]
### Patterns Discovered
- [anything that should be in CLAUDE.md or agent memory]
```

**When to write**: At end of multi-agent workflows (feature-team, release-team, full-team). Not for every single-agent task — that's overhead without value.

**Model allocation**: Product-owner-assistant (opus) writes the summary as part of its coordination role. No additional model cost — it's already the last agent to run.

### Non-Changes (Explicitly Rejected)

| Idea | Why Not |
|------|---------|
| ChromaDB for agent memory | Couples library to technology. Overkill at this scale. See Part 2. |
| Vector embeddings for episode retrieval | Markdown files with 50-100 lines don't need similarity search. |
| Auto-consolidation (episodes → facts) | The consolidation decision requires human judgment. Automate the trigger, not the decision. |
| Hierarchical paging (MemGPT-style) | Sessions are minutes to hours, not months. Compaction + MEMORY.md is sufficient. |
| `/consolidate` skill | Premature. Run `/document` with an instruction to review agent memories first. If this becomes a repeated workflow, promote it to a skill then. |
| Separate `lessons.md` per project | Agent MEMORY.md already serves this purpose once agents actually write to it. Don't create parallel stores. |

### Change 5: Crash-Recovery Checkpoints

**Problem**: All four changes above address knowledge persistence across sessions. But they don't solve the mid-session crash problem: when a team workflow crashes (context overflow, network error, IDE crash), all in-progress state is lost. The session handoff protocol (Change 4) only writes at the END of a successful workflow — useless for recovery.

**Mechanism**: Agents persist their progress checkpoints to a shared file on disk during active workflows. A new session can read this file to detect and resume interrupted work.

**File**: `.claude/memory/checkpoints/active.md` (project-scoped, NOT git-tracked)

**Design decisions**:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Single file vs per-agent | **Single shared file** | Simpler recovery (one file to read), natural chronological ordering, consistent with team-findings.md pattern |
| Write frequency | **Same as existing Checkpoint Protocol** | START, PROGRESS, BLOCKED, DONE — already defined in each AGENT.md |
| Write mode | **Append-only** | Crash-safe — partial writes don't corrupt earlier entries |
| Entry size | **< 200 characters** | Just enough to reconstruct state, not a full log |
| Lifecycle | **Created at workflow start, deleted on success** | Presence of the file = interrupted workflow |

**File format**:
```markdown
# Workflow Checkpoint

## Workflow
- **Team**: feature-team
- **Goal**: Implement user authentication
- **Started**: 2026-05-27T14:30:00
- **Agents**: developer, tester, documentarian

---

### [14:30:12] orchestrator | PLAN
Task breakdown: 1. Developer: JWT middleware 2. Tester: auth tests 3. Documentarian: update docs

### [14:31:05] developer | START
Starting JWT middleware. Plan: Add token validation decorator.

### [14:33:22] developer | PROGRESS
Modified `src/auth/middleware.py` — Added require_auth decorator.

### [14:36:45] developer | DONE
Completed JWT middleware. 3 files modified, 87 lines added.

### [14:37:02] tester | START
Starting test analysis for auth module. Scope: unit tests.
```

**Recovery protocol** (handled by PO assistant or team lead):
1. On session start, check if `.claude/memory/checkpoints/active.md` exists
2. If yes: parse last status per agent, present recovery summary to user
3. User chooses: Resume (skip completed agents), Restart (delete checkpoint), or Review (read full log)
4. On resume: append a RESUMED entry and continue from the interruption point

**Relationship to other memory layers**:

| Layer | Purpose | Survives crash? |
|-------|---------|----------------|
| Working memory (context window) | Current task state | No — lost on crash |
| **Checkpoints** (`active.md`) | In-progress workflow state | **Yes — this is the fix** |
| Episodic memory (agent MEMORY.md) | Learned patterns | Yes — persisted when written |
| Team findings (`team-findings.md`) | Cross-agent discoveries | Yes — persisted when written |
| Session handoffs (`sessions/`) | End-of-workflow summary | Only if workflow completed |
| Semantic memory (CLAUDE.md) | Distilled project facts | Yes — git-tracked |

**Priority**: **P1.5** — more urgent than team-findings (P2) because crashes cause immediate data loss, while team-findings is an optimization.

**Implementation**: Each AGENT.md gets a "Crash-Recovery Checkpoints" subsection. Each team composition gets a "Crash Recovery" section. The PO assistant gets a full "Crash Recovery Protocol" section.

---

## Part 5: Model Allocation for Memory Tasks

| Task | Model | Rationale |
|------|-------|-----------|
| Reading memory at session start | (no cost) | Injected into system prompt automatically |
| Writing to agent MEMORY.md | Same as agent's model | Part of the agent's normal workflow |
| Writing to team-findings.md | Same as agent's model | One-liner appends, minimal cost |
| Consolidating team-findings → CLAUDE.md | **Sonnet** (documentarian) | Summarization task. Sonnet is sufficient and 5x cheaper than Opus. |
| Session handoff summaries | **Opus** (PO assistant) | Already running as orchestrator. No additional model spawn. |
| Compaction (context window) | (automatic) | Built into Claude Code. No model choice. |

**Key insight**: Memory management should NOT require spawning additional agents. Every memory operation happens within an agent's existing workflow. The only "memory work" that uses a separate model is consolidation via the documentarian (already Sonnet).

---

## Part 6: Implementation Priority

| Priority | Change | Effort | Impact |
|----------|--------|--------|--------|
| **P0** | Add memory instructions to all AGENT.md files | Low — template text | Unlocks the entire memory system that's currently dormant |
| **P1** | Switch scope from `user` to `project` | Low — one-line change per agent | Prevents cross-project contamination |
| **P2** | Add team-findings.md convention and orchestrator instructions | Medium — update PO assistant + team definitions | Enables cross-agent knowledge sharing |
| **P3** | Add session handoff protocol to PO assistant | Medium — update AGENT.md + team definitions | Enables cross-session continuity |

P0 and P1 can be done immediately. P2 and P3 require testing with actual multi-agent workflows to validate the protocol.

---

## Part 7: What the Infographic Gets Right and Wrong (for Our Case)

**Right:**
- Procedural memory as a skill library — we already have this
- The consolidation problem is the hardest part — confirmed
- Working memory alone is not memory — confirmed (agents forget everything between sessions)
- Combine episodic + semantic for production — this is what MEMORY.md + CLAUDE.md gives us

**Wrong (for our context):**
- Vector stores for episodic memory — overkill for file-based agent systems
- Hierarchical paging — irrelevant for session-length agent lifetimes
- The diagram implies these are separate systems to build — in Claude Code, they're mostly the same system (markdown files) at different scopes

**Missing:**
- **Shared/team memory** — the diagram assumes a single agent. Multi-agent systems need coordination memory.
- **Reflective/meta memory** — agents knowing what they know and don't know. Our agents should check memory before exploring a codebase section they may have already mapped.
- **Memory scope** — the diagram doesn't address the question of what's user-global vs. project-local. For shared agent libraries, this is critical.
