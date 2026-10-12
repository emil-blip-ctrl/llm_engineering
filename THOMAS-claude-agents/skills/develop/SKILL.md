---
name: develop
version: 1.1.0
type: methodological
category: software-engineering
standards:
  - SOLID principles (Robert C. Martin)
  - Clean Code (Robert C. Martin)
  - Conventional Commits 1.0
description: >
  Implement a feature or fix a bug. Reads project context and team findings,
  plans the implementation, writes code following SOLID/Clean Code principles,
  performs a self-review, and reports changes with testing requirements.
  Use when the user says "implement", "build", "code", "fix", or "add feature".
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task, TodoWrite
---

# /develop — Feature Implementation Workflow

## Step 1: Gather Context

Read these sources before writing a single line of code:

1. **`CLAUDE.md`** — project architecture, patterns, build commands, gotchas
2. **`.claude/memory/MEMORY.md`** — accumulated project-specific patterns
3. **`.claude/memory/team-findings.md`** (if it exists) — discoveries from other agents that may affect this implementation

If anything in the request is ambiguous, ask one focused clarifying question before proceeding. Do not ask multiple questions at once.

## Step 2: Explore the Affected Area

```bash
git status --short
git log --oneline -5
```

For each module or file involved:
1. Read the file to understand existing patterns
2. Identify naming conventions, error handling style, import order
3. Find related tests to understand expected contracts
4. Check for shared utilities you should reuse (search before writing new helpers)

Report what you found: file paths, patterns, anything surprising.

## Step 3: Plan

Create a task list with `TodoWrite`:
- One entry per file to create or modify
- One entry per new dependency (with justification)
- Flag any file that touches shared state or public contracts (high-risk)
- Estimate: is this under 10 lines, under 100 lines, or larger?

Present the plan in 3–5 bullet points. Wait for implicit approval (user does not object) before proceeding to Step 4.

## Step 4: Implement

For each task in the plan:
1. Read the file before editing
2. Make the **minimal change** that satisfies the requirement
3. Follow existing patterns — do not introduce new patterns without asking
4. No refactoring of surrounding code unless explicitly requested
5. No new dependencies without stating the package name and reason
6. For `.ipynb` notebook files: use `NotebookEdit`, never raw JSON edits

Security checklist (apply to every change):
- [ ] No secrets, tokens, or credentials in code or comments
- [ ] User input validated at system boundaries
- [ ] No SQL built by string concatenation — use parameterized queries
- [ ] File paths sanitized before use
- [ ] External data deserialized safely (no `eval`, `pickle` from untrusted sources)

## Step 5: Self-Review

Before reporting, review your own changes:
1. Does each function/class do exactly one thing? (SRP)
2. Are there any obvious bugs or off-by-one errors?
3. Is there duplicate logic that should be extracted?
4. Did you introduce any breaking changes to existing public APIs?
5. Are there side effects that could affect unrelated functionality?

Fix anything you catch. Do not report issues you already know how to fix.

## Step 6: Write to team-findings.md

If you discovered something other agents should know (a gotcha, a hidden dependency, an infrastructure constraint), append it to `.claude/memory/team-findings.md`:

```
[YYYY-MM-DD] developer — <one-line finding, file:line reference>
```

## Step 7: Report

```
## Changes Made
- `path/to/file.py:L12-45` — Added `X` function: <one-line purpose>
- `path/to/other.py:L78`   — Modified `Z` to handle <case>

## Dependencies Added
- `package-name==version` — Reason: ...

## Security Notes
- <any security-relevant decision made, or "none">

## Ready for Testing
- [ ] Unit tests needed for: <function/class names>
- [ ] Integration tests needed for: <interaction points>
- [ ] Edge cases to cover: <list>
```
