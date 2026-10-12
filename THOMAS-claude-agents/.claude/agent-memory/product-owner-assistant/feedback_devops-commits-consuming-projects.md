---
name: devops-commits-consuming-projects
description: In consuming projects (e.g. THDKnowledgeMgt), delegate git commits to the devops agent rather than handing the human raw commands
metadata:
  type: feedback
---

In **consuming projects** (e.g. THDKnowledgeMgt), the PO wants the **devops agent** to perform git commits — do NOT just hand over copy-paste commands for the human to run.

**Why:** Stated by the PO on 2026-06-15. They consider committing part of the devops role for their own project repos, and prefer the agent to execute it end-to-end.

**How to apply:**
- Delegate the commit to devops with a tightly scoped `git add` (only the intended files) + a clear commit message; have devops report the resulting commit hash. Default to commit-only (no push) unless the PO asks to push.
- This does NOT apply to the **Claude Agents library repo**, which keeps its human-only commit guard (PreToolUse hook blocks agent commits; only librarian/library-engineer may edit, human commits). See [[library-commit-human-only]].
