---
name: review
version: 1.1.0
type: methodological
category: software-engineering
standards:
  - SOLID principles
  - OWASP Top 10 (2021)
  - IBM Integration best practices
description: >
  Review code for correctness, security, performance, and adherence to project
  standards. Checks for SOLID violations, OWASP vulnerabilities, architectural
  consistency, and IBM APIC/ACE integration patterns. Use when the user says
  "review", "check code", "code quality", or before merging a PR.
allowed-tools: Read, Grep, Glob, Task, Bash, TodoWrite
---

# /review — Code Review Workflow

## Step 1: Identify Scope

```bash
# Changed files since last commit or in staging
git diff --name-only HEAD~1 2>/dev/null || git diff --name-only --cached 2>/dev/null || git status --short

# For PR review: list all commits
git log --oneline origin/main..HEAD 2>/dev/null || git log --oneline -10
```

List the files to review and their module context before reading any of them.

## Step 2: Read Changed Files

For each changed file:
1. Read the **full file** — not just the diff — to understand context
2. Read at least one related test file to understand the contract
3. Note the file's module, layer (API / domain / infra), and dependencies

## Step 3: Checklist

### Architecture & Design
- [ ] Changes follow existing project patterns (module structure, folder layout)
- [ ] No circular dependencies introduced
- [ ] Single Responsibility: each new function/class has one clear purpose
- [ ] No unnecessary coupling between modules
- [ ] Public API surface is minimal — nothing exposed that doesn't need to be
- [ ] New abstractions are justified — three occurrences before extracting

### Code Quality
- [ ] Names are intention-revealing (no `x`, `tmp`, `data`, `process`)
- [ ] No dead code or commented-out blocks
- [ ] No duplicate logic (DRY — but no premature abstraction)
- [ ] Error handling is appropriate: not swallowed silently, not over-engineered
- [ ] No hardcoded values that belong in config (URLs, timeouts, limits)
- [ ] Functions stay under ~30 lines; classes under ~200 lines

### Security (OWASP Top 10)
- [ ] No secrets, API keys, or credentials in code, comments, or config files
- [ ] Input validated at all system boundaries (HTTP, file, CLI)
- [ ] No SQL injection — parameterized queries only
- [ ] No XSS — output encoded before rendering
- [ ] No path traversal — file paths sanitized
- [ ] No unsafe deserialization (`eval`, `pickle` from untrusted sources)
- [ ] Dependencies from trusted sources only; no unpinned versions in prod

### Performance
- [ ] No N+1 query patterns in loops
- [ ] Heavy operations not running on the hot path without caching/async
- [ ] No unbounded result sets (pagination or LIMIT applied)
- [ ] File/connection resources closed properly (context managers)

### Language-Specific

**Python**
- [ ] Type hints on all public function signatures
- [ ] No mutable default arguments (`def f(x=[])`)
- [ ] Context managers for files, DB connections, locks
- [ ] No bare `except:` — catch specific exceptions

**JavaScript / TypeScript**
- [ ] `async/await` used consistently (no mixed `.then()` / `await`)
- [ ] No `any` in TypeScript without a comment explaining why
- [ ] `null` / `undefined` handled explicitly at boundaries

### IBM Integration (APIC / ACE / MQ)
- [ ] All API requests target the APIC gateway — never direct ACE endpoints
- [ ] Auth headers use `X-IBM-Client-Id` / `X-IBM-Client-Secret` or JWT — not `userName/password`
- [ ] OpenAPI specs include `x-ibm-configuration` assembly sections
- [ ] MQ interactions handle dead-letter queues and correlation IDs
- [ ] ACE ESQL compute nodes do not call external services directly

### Testing
- [ ] New code has corresponding tests (or explicit justification for why not)
- [ ] Tests are independent — no shared mutable state between test cases
- [ ] Edge cases covered: empty input, `None`/`null`, boundary values, error paths
- [ ] No test that only verifies implementation internals (test behavior, not wiring)

### Git & Commit Hygiene
- [ ] Commit messages are imperative, under 72 chars in the subject line
- [ ] No unrelated changes bundled in the same commit
- [ ] No debug statements, `console.log`, or `print` left in code
- [ ] No `.env`, lock files with secrets, or large binaries added to git

## Step 4: Report

```
## Code Review: <scope — file name or PR title>

### Summary
<2-3 sentence overall assessment: what was changed and overall quality>

### Issues Found
| Severity | File | Line | Issue | Suggestion |
|----------|------|------|-------|-----------|
| 🔴 High   | path/to/file.py | 42 | SQL injection risk | Use parameterized query |
| 🟡 Medium | path/to/file.py | 78 | Bare except clause | Catch `ValueError` specifically |
| 🔵 Low    | path/to/file.py | 15 | Unclear variable name | Rename `x` to `retry_count` |

Severity guide:
- 🔴 High   — Security risk, data loss, crash, or broken contract. Must fix before merge.
- 🟡 Medium — Maintainability, error handling, test gap. Should fix.
- 🔵 Low    — Style, naming, minor. Can fix in follow-up.

### Positive Observations
- <what was done well — be specific, not generic>

### Verdict
- [ ] ✅ Approve — Ready to merge
- [ ] 🔄 Request changes — High/Medium issues must be resolved first
- [ ] 💬 Comment — Low issues only; can merge as-is with optional follow-up
```
