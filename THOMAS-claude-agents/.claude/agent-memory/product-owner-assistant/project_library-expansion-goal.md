---
name: library-expansion-goal
description: PO's strategic goal to fill the Agentic-Claude library with real leverageable resources (not just references), hybrid core + integration/EA layer
metadata:
  type: project
---

The PO (Thomas) wants the Agentic-Claude library to contain **actual leverageable resources** — populated teams, agents, deep skills, hooks — not just reference links to other libraries (anthropics/skills etc.). Stated 2026-06-09: "we have a good framework but the skills are quite empty."

Direction chosen for the expansion:
- **Hybrid orientation**: keep a reusable general SDLC core (dev/test/devops/docs) AND add a specialized enterprise-integration & EA layer (APIC/ACE/MQ, CMDB→Archimate, BA).
- **Top-to-bottom design must include the distribution layer** (plugin / marketplace / library management) as the TOP layer, not just teams→agents→skills→tools.
- **MCP deferred** for the first pass.
- Approach: **blueprint now, build in waves** (prioritized backlog), delivered as `docs/library-expansion-proposal.md`.

**Why:** the framework (governance, distribution, memory, teams) is mature but the skill bodies are thin workflow stubs; the PO wants depth and breadth that the team can actually invoke.

**How to apply:** when proposing/building library resources, favor concrete, deep, immediately-usable content over references; lead integration/EA additions with the PO's real stack (APIC/ACE/MQ, CMDB→Archimate). All library edits go through librarian/library-engineer, recommend-first, human commits. See [[library-commit-human-only]].

## Scale & platform taxonomy (added 2026-06-11)
The tech-adaptation effort is **~300 technologies** across the TCS platform taxonomy (4 groups): **Customer Journey** (Digital Platforms TCS.CH/TCS App, SF.MCE & MCP, GCC); **Business Capability** (SF.SC, FSM, IDIT, SAP, HR, Camping.care); **Data Capability** (Business SaaS, BI, Big Data); **Core IT** (Collaboration M365/ESM/Jira-Conf, Doc Mgt, Azure SaaS, Internal Developer Platform: CI/CD, PaaS, MOEx, IAM, CMDB, Monitoring/Obs, Infrastructure). Detailed per-platform technology lists to come later.

**Decided design direction (research-backed, ecosystem Pattern B+C):** skills stay technology-AGNOSTIC (workflow-shaped); technology specifics live in a **central hierarchical knowledge base** (`knowledge/<group>/<platform>/<tech>.md`) referenced by role agents/skills — NOT per-tech agents and NOT per-skill duplication. Platform **teams** = compositions of existing role agents pointed at a KB subtree.

**Why:** at 300 techs, per-tech agents/skills or per-skill bundles are unmaintainable; central KB + on-demand authoring is the only scalable path. PO is explicitly cautious about scale.

**How to apply:** do NOT attempt to author 300 packs. Build KB schema + a pack TEMPLATE + governance approach first, then a single pilot platform, then scale incrementally / create-on-first-use. Governance must NOT enumerate 300 packs in the CLAUDE.md inventory — use a KB index + template-conformance lint instead.

**LOCKED decisions (2026-06-11):** (1) Central hierarchical KB confirmed. (2) Platform teams at **per-platform granularity (~16 teams)**, one per platform in the taxonomy (CJ: Digital Platforms, SF.MCE & MCP, GCC; BC: SF.SC, FSM, IDIT, SAP, HR, Camping.care; DC: Business SaaS, BI, Big Data; Core IT: Collaboration, Doc Mgt, Azure SaaS, Internal Developer Platform). (3) First build step = architecture/template design + an EMPTY skeleton folder tree to platform level (no tech packs, no team files yet). Teams + packs come in later pilot/scale waves.
