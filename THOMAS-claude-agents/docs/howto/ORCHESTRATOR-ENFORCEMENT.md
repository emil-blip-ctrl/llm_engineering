# PO Orchestrator Enforcement — Setup & Future Improvements

This note documents how the repo enforces "every interactive turn runs as the
Product Owner Assistant (PO) orchestrator," and the open improvements for
cross-platform and cross-project coverage.

## What ships today

Two complementary mechanisms, both at **project scope** (this repo's `.claude/`):

| Mechanism | File | Effect |
|-----------|------|--------|
| **Output style** | [`.claude/output-styles/product-owner-orchestrator.md`](../../.claude/output-styles/product-owner-orchestrator.md) | Reshapes the main agent's system prompt so it *is* the PO orchestrator — coordinate & delegate, never implement directly. Activate with `/output-style` → **PO Orchestrator**. |
| **UserPromptSubmit hook** | [`.claude/hooks/po-orchestrator-reminder.ps1`](../../.claude/hooks/po-orchestrator-reminder.ps1), wired in [`.claude/settings.json`](../../.claude/settings.json) | Injects the orchestration directive into context on **every** prompt. Deterministic — survives context compaction and fires even when no output style is active. Exits 0; never blocks. |

### Why both

- The output style is the clean, low-overhead path: the top-level agent already
  behaves as the PO, keeps interactivity (`AskUserQuestion` works), and avoids
  spawning a subagent on every trivial turn.
- The hook is the belt-and-suspenders: a per-turn reminder that does not depend
  on the user remembering to switch styles.

### Known limitation

Neither mechanism can **force** a `Task`-tool delegation — the main loop always
decides. They make the orchestrator persona the strong default; they do not
hard-guarantee delegation. Forcing a subagent on every turn was rejected because
it loses interactivity and adds spawn cost per turn.

## Future improvements

### 1. macOS / Linux support (`.js` twin)

The reminder hook is currently **PowerShell-only**. PowerShell 5.1 is not present
on macOS/Linux by default (whereas `node` ships with Claude Code). Mirror the
pattern already used by the commit guard, which has both a `.ps1` and a `.js`
form:

- Add `.claude/hooks/po-orchestrator-reminder.js` that writes the same directive
  string to stdout and exits 0.
- On macOS/Linux, swap the `settings.json` command to:
  ```
  node "$CLAUDE_PROJECT_DIR/.claude/hooks/po-orchestrator-reminder.js"
  ```
- Keep the two twins byte-for-byte in sync on the directive text (same
  maintenance rule the repo already applies to `pre-commit-guard.{ps1,js}`).

### 2. User-level (all-projects) install

Today the enforcement only applies in **this** repo's working directory. To make
the PO orchestrator the default across **every** project opened in the VSCode
Claude UI:

- Copy the output style to `~/.claude/output-styles/product-owner-orchestrator.md`.
- Copy the hook script to `~/.claude/hooks/` and add the `UserPromptSubmit` block
  to `~/.claude/settings.json` (user scope).

**Caveat — agent availability.** Routing through the PO only makes sense where
the specialist agents (developer/tester/devops/documentarian/architect) actually
exist. They are present in projects that install this library (via plugin or
symlinks) but absent elsewhere. A user-level install would inject the directive
into *unrelated* projects where delegation targets don't resolve. Options:

- Accept the soft degradation (directive is advisory; if no agents exist, the
  main agent just proceeds normally).
- Or gate the hook: have the script check for `.claude/agents/` (or the plugin)
  and emit the directive only when the PO/specialist agents are present —
  no-op otherwise.

### 3. Optionally ship as part of the library

If user feedback shows this is broadly wanted, fold both artifacts into the
installer (`templates/install.ps1` / `setup.ps1`) and the plugin so consuming
projects can opt in, rather than hand-copying. This would be a
`repo-improvement-team` change (librarian for the docs/definitions,
library-engineer for the installer wiring).
