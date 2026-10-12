---
name: library-commit-human-only
description: In the Agentic-Claude library repo, a human is always the committer; agents recommend/apply but never commit or push
metadata:
  type: feedback
---

In the Agentic-Claude library repo, **never run `git commit`/`git push`** — provide ready-to-run commands instead and let the human commit. The PO confirmed this on 2026-06-09 ("ok my point..." flow): even after explicit "do commit and push", I correctly declined and supplied commands.

**Why:** the library is shared by every consuming project and is self-modifying; the human-in-the-loop committer is the real guardrail against unreviewed drift. A `PreToolUse` commit-guard hook also enforces inventory-vs-disk and frontmatter checks at the git level. Only the repo-improvement-team (librarian + library-engineer) may modify the repo, recommend-first.

**How to apply:** after any approved library edit, summarize changes and hand over a single ready-to-paste commit/push block; confirm the commit-guard will pass (skill/agent/team counts match disk, frontmatter has name/description). Relates to [[library-expansion-goal]].
