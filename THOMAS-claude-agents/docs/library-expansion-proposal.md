# Library Expansion Proposal — Blueprint & Build Backlog

**Date:** 2026-06-09
**Author:** librarian (repo-improvement-team), RECOMMEND mode
**Status:** PROPOSAL — blueprint and backlog only. **No changes** to any `AGENT.md` / `SKILL.md` / team file or the [CLAUDE.md](../CLAUDE.md) inventory in this pass. Edits happen only after the PO approves specific items, and the human commits.

---

## 0. Vision & Principles

**The problem (PO, 2026-06-09):** *"We have a good framework but the skills are quite empty."* The framework — 8 agents, 9 skills, 4 teams, plugin packaging, commit-guard governance — is solid. What is thin is **leverageable depth**: the library mostly holds single-file workflows and external *references* rather than *resources* an agent can pick up and apply (templates, checklists, reference data, scaffolds, hooks).

A nuance worth stating plainly: the core skills are **not** shallow as *prose* — [`/develop`](../skills/develop/SKILL.md), [`/review`](../skills/review/SKILL.md), [`/security-audit`](../skills/security-audit/SKILL.md) and [`/pattern-diagram-design`](../skills/pattern-diagram-design/SKILL.md) carry real step-by-step procedure and checklists. The gap is **bundled resources via progressive disclosure**: only `publish-confluence` ships a companion file ([CONVENTIONS.md](../skills/publish-confluence/CONVENTIONS.md)). The other eight are one `SKILL.md` each — no templates, no reference catalogs, no scaffolds. That is the "empty" the PO feels: a skill that *describes* a Postman collection but ships no skeleton; a `/review` that lists checks but bundles no language-specific checklist files to load on demand.

### Principles

1. **Resources, not references (MANDATED library rule, PO 2026-06-09).** *Every skill must bundle at least one loadable artifact (template / checklist / scaffold) — progressive disclosure.* This is no longer a recommendation: it is a stated library rule. A skill that only points at an external repo, or inlines everything into `SKILL.md`, does not meet the bar. References belong in the ecosystem survey, not in a skill body.
2. **Hybrid catalog.** Keep a reusable, general SDLC **core** (develop/test/review/deploy/document/refactor/debug/api-design) AND grow a specialized **enterprise-integration & EA layer** (APIC/ACE/MQ, CMDB→Archimate, OpenAPI/WSDL, message-flow tracing, BA). Lead the integration/EA additions with the PO's real stack — that is our differentiator (see [ecosystem survey](ecosystem-survey-github-popularity.md), Part B: middleware integration is an ecosystem gap).
3. **Governance unchanged.** Recommend → human approves → apply → **human commits**. Only the [repo-improvement-team](../teams/repo-improvement-team.md) edits this repo; the [commit-guard](../.claude/hooks/pre-commit-guard.ps1) gates inventory drift and frontmatter.
4. **Per-object semver, single plugin.** Each object keeps its informational `version:`; the whole bundle ships and pins as one plugin semver. Build in **waves** — each wave is a release train.
5. **Least privilege everywhere.** New agents/skills get the minimal tool set for their job; hooks default to deny-first. Tie to the lethal-trifecta defenses surfaced in the survey (Part C.2).

---

## 1. Layer 0 — Distribution & Packaging (top of the plan)

As the catalog grows from ~21 objects toward ~35+, the packaging question is: **one plugin, or sub-bundles?**

### Recommendation: stay single-plugin, organize by tag/category

| Option | Pro | Con | Verdict |
|--------|-----|-----|---------|
| **Single plugin** (`agentic-claude`), tag/category-organized | One thing to install, one version to pin, one tag to cut, commit-guard already covers it; matches Claude Code's "plugin is the installable unit" model | The bundle gets larger; a consumer who only wants core SDLC still gets the EA layer | **CHOSEN** |
| Sub-bundles (`agentic-core`, `agentic-integration-ea`) | Lean installs; EA consumers and pure-dev consumers diverge cleanly | 2–3× the release/version/tag/marketplace overhead; cross-bundle team compositions (e.g. a team mixing core + EA agents) become awkward; doubles the commit-guard surface | Defer — revisit only if the EA layer outgrows core or an external consumer demands core-only |

**Rationale:** pinning simplicity wins. Claude Code pins a *plugin*, not an agent; sub-bundles multiply the pin/version/tag matrix for a library that is still small. We get most of the "lean" benefit for free because agents/skills are **opt-in at install** (selective `install.ps1`, or junction only what you want) even within one plugin.

### Scaling the catalog within one plugin

- **Marketplace categorization/tags.** Add a `category` + `keywords` convention to [`marketplace.json`](../.claude-plugin/marketplace.json) so the catalog entry advertises domains: `core-sdlc`, `integration`, `enterprise-architecture`, `governance`. Tag each agent/skill in its frontmatter (`category:`) so the inventory tables and Confluence pages can group by domain instead of one flat list. (Informational only — Claude Code still installs the whole plugin.)
- **Versioning per wave.** Each wave = one plugin minor bump (`v1.3.0`, `v1.4.0`…). Bump the `version:` of every object that changed in the wave (commit-guard already enforces bump-on-change parity), then bump `plugin.json` + `marketplace.json`, then tag. Cut a `CHANGELOG.md` section per wave listing NEW vs ENRICH.
- **Install modes unchanged.** Track-latest (user junctions) and pinned (project-scope plugin) both keep working as documented in CLAUDE.md. Add the SHA-pin recipe the survey recommended (Part C.4) for reproducible prod installs — a docs-only change.
- **Commit-guard + inventory scaling.** The guard already blocks when CLAUDE.md lists fewer objects than exist on disk. As we add objects, **extend the guard** to also check the proposed `category:` field exists (one new lint), and keep the `.ps1`/`.js` twins in parity. The inventory tables grow but stay one-per-domain-sortable.

---

## 2. Layer 1 — Teams

Keep teams pertinent — resist proliferation. Existing 4 stay. **1 new team — `integration-team` — APPROVED (PO 2026-06-09)** (integration/EA work currently has no composition, despite being our differentiator).

| Team | Status | Members | When to use |
|------|--------|---------|-------------|
| [`feature-team`](../teams/feature-team.md) | existing | developer + tester + documentarian | Implement a feature end-to-end |
| [`release-team`](../teams/release-team.md) | existing | devops + tester + documentarian | Prepare and validate a release |
| [`full-team`](../teams/full-team.md) | existing | all 6 delivery agents | Major features, bootstrapping, migrations |
| [`repo-improvement-team`](../teams/repo-improvement-team.md) | existing | PO (lead) + librarian + library-engineer | Modify this library itself (the only team that may) |
| **`integration-team`** | **APPROVED (2026-06-09)** | architect (lead) + business-analyst + tester | Analyze/design an integration: map dependencies, choose pattern, produce SP/diagrams, derive test scenarios. Pairs `architect` (pattern + dependency) with `business-analyst` (requirements/SP-to-Jira) and `tester` (scenario derivation, already a consumer of `pattern-diagram-design`). |

**Justification for `integration-team`:** the architect + new BA + tester already collaborate informally (the `pattern-diagram-design` skill notes the tester derives test scenarios from it). A standing composition with clear file boundaries (architect owns `docs/architecture/`, BA owns `docs/requirements/`, tester owns `tests/`) makes the EA workflow repeatable. **Not proposing** a separate "data-migration" or "api-review" team — those are single-skill invocations, not recurring multi-agent flows (per [TEAM-AUTHORING](howto/TEAM-AUTHORING.md): don't create a team for one-off or single-agent work).

---

## 3. Layer 2 — Agents

Existing 8 stay. **1 new agent — `business-analyst` — APPROVED (PO 2026-06-09).** The bar against over-proliferation held; the BA cleared it as a distinct discipline.

| Agent | Status | Role | Key responsibilities | Tools (least-privilege) | Memory |
|-------|--------|------|----------------------|-------------------------|--------|
| [`developer`](../agents/developer/AGENT.md) | existing | Implementation | SOLID/Clean Code, production code only | Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch, WebFetch, NotebookEdit | project |
| [`tester`](../agents/tester/AGENT.md) | existing | Quality | ISTQB tests, execution | Read, Write, Edit, Bash, Grep, Glob, Task | project |
| [`devops`](../agents/devops/AGENT.md) | existing | CI/CD | Actions, Azure, Docker, SBOM | Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch, WebFetch | project |
| [`documentarian`](../agents/documentarian/AGENT.md) | existing | Docs | CLAUDE.md, ADRs, findings consolidation | Read, Write, Edit, Grep, Glob, Task, WebSearch | project |
| [`product-owner-assistant`](../agents/product-owner-assistant/AGENT.md) | existing | Orchestration | Backlog, prioritization, coordination, Atlassian | Read, Grep, Glob, Task, WebSearch, WebFetch, TodoWrite, AskUserQuestion, Atlassian MCP | project |
| [`architect`](../agents/architect/AGENT.md) | existing | Integration architecture | APIC/ACE/MQ analysis, dependency mapping, patterns | Read, Write, Edit, Grep, Glob, Task, WebSearch, WebFetch, TodoWrite | project |
| [`librarian`](../agents/librarian/AGENT.md) | existing | Library definitions | Maintains this repo's defs/docs (team-only) | Read, Write, Edit, Grep, Glob, Task, WebSearch, WebFetch | project |
| [`library-engineer`](../agents/library-engineer/AGENT.md) | existing | Library tooling | Maintains scripts/hooks (team-only) | Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch | project |
| **`business-analyst`** | **APPROVED (2026-06-09)** | Requirements & process analysis | Elicit/refine requirements, write user stories & acceptance criteria, stakeholder & process analysis, maintain System-Process pages and Jira linkage; supports CMDB→Archimate business-layer mapping. **Boundary vs PO-assistant:** owns *what the requirement is* (elicitation, AC, traceability, `docs/requirements/`); the PO-assistant owns *what to build next & who does it* (orchestration/prioritization). | Read, Grep, Glob, Task, WebSearch, WebFetch, TodoWrite, AskUserQuestion, Atlassian MCP — **no Write/Edit/Bash** (least-privilege; delegates artifact writes to documentarian) | project |

**The clearest gap — a dedicated Business-Analyst, distinct from the PO-assistant.** The survey (Part A, "BA is under-served"; Part B, "we lead on a coherent BA capability") flags BA as both an ecosystem gap *and* a strength we only partially realize today. Right now BA work is smeared across the `product-owner-assistant` (coordination/prioritization) and the `architect` (SP pages, patterns). These are **different disciplines**:

- **PO-assistant** = *what to build next and who does it* — orchestration, prioritization, delegation. It is the orchestration layer; it should not also own requirements engineering.
- **business-analyst** = *what the requirement actually is* — elicitation, acceptance criteria, process/stakeholder analysis, traceability (story ↔ SP ↔ Jira). A distinct discipline with its own deliverables (`docs/requirements/`).

Per [AGENT-AUTHORING](howto/AGENT-AUTHORING.md) the bar for a new agent is "a distinct discipline with a distinct tool set, isolated expertise, or a file boundary." BA clears it: distinct deliverables, read-only-on-code boundary (like the PO it never writes code, but unlike the PO it produces requirement artifacts and owns the SP/Jira linkage that `pattern-diagram-design` already references). **No other new agents proposed** — resist the ecosystem's "100+ subagents" sprawl (survey Part A); our roles stay deliberately enterprise-scoped.

---

## 4. Layer 3 — Skills (the heart)

For each skill: **ENRICH** (exists; deepen body + add bundled resources per progressive disclosure) or **NEW** (create). Mapped to owning agent(s)/team(s).

### Depth standard (MANDATED — so no skill ships as a thin stub)

**Library rule (PO 2026-06-09):** *Every skill must bundle at least one loadable artifact (template / checklist / scaffold) — progressive disclosure.* This is mandatory for new skills **and** for ENRICH items: every ENRICH must bring an existing thin skill up to this standard (it is not optional polish — it is the bar that closes the "skills are empty" gap). A future commit-guard check will enforce it (see Layer 4 and the Wave-2 backlog).

Every skill — enriched or new — must meet **all** of:

1. **Frontmatter** — `name`, `description` (third-person, what + when/trigger phrases), `allowed-tools` (least-privilege), `version`, and the new `category`.
2. **Workflow** — ≥4 numbered steps: gather context → analyze/plan → execute → **structured Report** (per [SKILL-AUTHORING](howto/SKILL-AUTHORING.md)).
3. **At least one bundled resource** loaded on demand (progressive disclosure): a template, checklist, reference table/dataset, or scaffold file in the skill folder — **not** inlined into `SKILL.md`. This is the **mandated** rule (PO 2026-06-09) that fixes "skills are empty," and the one a future commit-guard check will enforce.
4. **A worked example** showing input → output.
5. **Owner mapping** — names the agent(s)/team(s) that invoke it.

### Existing skills

| Skill | Action | Owner(s) | What to add |
|-------|--------|----------|-------------|
| [`develop`](../skills/develop/SKILL.md) | ENRICH | developer / feature-team | Bundle language-specific scaffolds + a Clean-Code checklist file; reference instead of re-listing the security checklist (share with `/review`). |
| [`test`](../skills/test/SKILL.md) | ENRICH | tester / feature-team | Bundle `conftest.py` / fixture templates, a parametrize cookbook, and an ISTQB technique cheat-sheet as companion files. |
| [`deploy`](../skills/deploy/SKILL.md) | ENRICH | devops / release-team | Bundle starter `ci.yml` / `deploy.yml` / `Dockerfile` / bicep templates as files; SKILL.md links them rather than embedding YAML. |
| [`review`](../skills/review/SKILL.md) | ENRICH | all delivery agents | Split the checklists into per-language companion files (`checklist-python.md`, `checklist-ts.md`, `checklist-apic.md`) loaded on demand. |
| [`document`](../skills/document/SKILL.md) | ENRICH | documentarian | Bundle ADR template, C4 diagram skeletons, and a CLAUDE.md section template as files. |
| [`security-audit`](../skills/security-audit/SKILL.md) | keep (deep) | tester / devops / architect | Already deep. Light: extract the OWASP grep-pack into a companion `patterns.md` so it's reusable and maintainable. |
| [`postman-collection-generator`](../skills/postman-collection-generator/SKILL.md) | ENRICH | architect / tester | Bundle a v2.1 collection skeleton + environment-file template + assertion-snippet library — the clearest "describes but ships nothing" case. |
| [`publish-confluence`](../skills/publish-confluence/SKILL.md) | keep (deep) | librarian / PO | Reference model for progressive disclosure (has CONVENTIONS.md). No change. |
| [`pattern-diagram-design`](../skills/pattern-diagram-design/SKILL.md) | ENRICH | architect / integration-team | Bundle the full ARCHI pattern catalog + Mermaid templates per pattern + the SP page scaffold as companion files (today they're inline). |

### New skills

| Skill | Owner(s) | 1-line purpose | Key procedures / bundled resources |
|-------|----------|----------------|-------------------------------------|
| **`refactor`** (NEW) | developer | Behavior-preserving code improvement | Refactoring catalog (Fowler) checklist; "characterization test first" gate; before/after diff report. |
| **`debug`** (NEW) | developer / tester | Systematic fault isolation | Hypothesis-log template; bisect/repro recipe; root-cause report scaffold. |
| **`api-design`** (NEW) | architect / developer | Design/review a REST API contract | OpenAPI 3.1 skeleton; naming & versioning checklist; error-model template; pairs with `postman-collection-generator`. |
| **`dependency-map`** (NEW) | architect / integration-team | Map system/service dependency chains from code+config | Dependency-matrix template; APIC→ACE→MQ traversal recipe; Mermaid graph scaffold; feeds `pattern-diagram-design`. |
| **`contract-analysis`** (NEW) | architect / integration-team | Analyze OpenAPI/WSDL/XSD contracts for breaking changes & coverage | Diff rules for breaking vs non-breaking; WSDL/XSD walk recipe; contract-report template. |
| **`message-flow-trace`** (NEW) | architect / tester | Trace a message across APIC/ACE/MQ hops incl. DLQ/correlation | Hop-by-hop trace template; correlation-ID checklist; EIP-vocabulary reference (shares with `pattern-diagram-design`). |
| **`cmdb-to-archimate`** (NEW) | architect / business-analyst / integration-team | Transform CMDB extracts into ArchiMate models | CMDB→ArchiMate element mapping table; layer-assignment rules; Archi/`.archimate` or Mermaid output scaffold. **Lead integration/EA skill — ties to the PO's real CMDB→Archimate project.** |
| **`requirements-elicitation`** (NEW) | business-analyst / integration-team | Turn intent into stories + acceptance criteria + traceability | User-story & Gherkin AC templates; INVEST checklist; story↔SP↔Jira traceability matrix (reuses `pattern-diagram-design` SP/Jira linkage). |

**Mapping note:** every integration/EA skill names `architect` and/or `integration-team`; BA-flavored skills name `business-analyst`. `pattern-diagram-design` becomes the hub the new integration skills cross-link into (dependency-map feeds it; message-flow-trace shares its EIP vocabulary; api-design + contract-analysis feed the contract side).

---

## 5. Layer 4 — Tools & Hooks

### Per-agent tool assignment for the new agent (least-privilege)

| Agent | Tools | Rationale |
|-------|-------|-----------|
| `business-analyst` | Read, Grep, Glob, Task, WebSearch, WebFetch, TodoWrite, AskUserQuestion, Atlassian MCP (`mcp__<server>__*`) | **No Write/Edit/Bash** — BA produces requirement *artifacts* via Task delegation to the documentarian, or writes only under `docs/requirements/` if we later grant scoped Write. Mirrors the PO-assistant's read-and-coordinate posture; Atlassian for Jira/Confluence story+SP traceability. Bash deliberately excluded (no need to run code). |

(No tool changes proposed for existing agents in this pass.)

### Proposed hooks catalog (project opt-in, shipped from the library)

Hooks rarely ship standalone in the ecosystem (survey Part A); a curated, opt-in catalog is a differentiator. Each ships as a `.ps1` + `.js` twin (matching the existing commit-guard convention) under `.claude/hooks/`, wired via a template `settings.json` block that consumers opt into.

| Hook | Lifecycle | Purpose | Governance rationale |
|------|-----------|---------|----------------------|
| **secret-scan / `.env` guard** | PreToolUse (Read/Write/Edit/Bash) | Block reads/writes of `.env*`, private keys, credential files; deny-first | Directly closes the **lethal-trifecta** exfiltration vector (survey Part C.2); the survey's quick-win "ship a `deny(Read(.env*))` example" (Part C.4). |
| **frontmatter / inventory linter** | PreToolUse (git commit) | **Extend** the existing commit-guard: also lint `version:`/`model:`/`category:` fields and twin-parity | Builds on an already-Strong dimension (Part C.4); keeps the growing inventory honest. |
| **depth-standard linter** | PreToolUse (git commit) | **Extend** the commit-guard: fail if any `skills/<name>/` contains only `SKILL.md` with no companion resource (template/checklist/scaffold) | Future enforcement of the **mandated** depth standard (PO 2026-06-09); machine-checks the "resources, not references" rule. |
| **test-on-edit** | PostToolUse (Edit/Write on `src/`) | After editing source, suggest/run the affected tests | Tightens the develop→test loop; opt-in so it never surprises a consumer. |
| **markdown / diagram lint** | PostToolUse (Edit/Write on `*.md`) | Validate Markdown + Mermaid fences (render-check) | Keeps the doc/diagram-heavy EA output (SP pages, ADRs) clean; cheap quality gate. |

All hooks are **opt-in** — consumers enable them in their project `settings.json`. The library ships them + a documented enable snippet; it never forces them. Permissions stay deny-first and scoped (survey Part C.2: deny > allow > ask).

---

## 6. Layer 5 — MCP (DEFERRED)

No design this pass — placeholder only. Future candidates (from survey Part B), to be scoped in a later wave:

- **Atlassian** — *already wired* into `product-owner-assistant` and `publish-confluence`. Baseline.
- **Postgres** (`crystaldba/postgres-mcp`) — governed DB read/perf analysis for integration data stores.
- **OpenAPI** (`janwilmake/openapi-mcp-server`) — wrap live APIC/ACE API surfaces; pairs with `api-design` / `contract-analysis`.
- **GitHub** (`github/github-mcp-server`) — repo/PR operations for devops/library workflows.
- **Custom APIC/ACE/MQ MCP** — the unfilled ecosystem gap (survey Part B: "no mature public option"); our strongest potential differentiator, but a build, not an adopt. Defer to a dedicated decision.

Open MCP questions (licensing posture, ownership, gateway/allowlist guardrails) are tracked in the survey's own Open Questions and Part C.4 — not re-opened here.

---

## 7. Build Backlog — Waves

Prioritized. Effort: S (<½ day), M (~1–2 days), L (multi-day). "Builder agent" is the repo-improvement-team member who would apply it once approved.

### Wave 1 — quick wins, highest value (enrich thin skills + the BA agent)

| Item | Type | Effort | Depends on | Builder | Value note |
|------|------|--------|------------|---------|------------|
| Enrich `postman-collection-generator` (bundle collection skeleton + env template + assertion lib) | skill | M | — | librarian | Clearest "describes but ships nothing" gap; high PO relevance (APIC/ACE testing). |
| Enrich `pattern-diagram-design` (extract catalog + per-pattern Mermaid templates + SP scaffold to files) | skill | M | — | librarian | Turns our deepest EA skill into reusable resources; unblocks integration skills. |
| Enrich `review` (split per-language checklists into companion files) | skill | S | — | librarian | Cheap, immediate progressive-disclosure win; pattern other enriches copy. |
| Add `business-analyst` agent | agent | M | — | librarian | The clearest role gap; distinct discipline from PO-assistant. |
| `secret-scan / .env guard` hook (.ps1 + .js twin + enable snippet) | hook | S | — | library-engineer | Lethal-trifecta defense; survey quick-win; deny-first default. |
| Add `category:` to frontmatter + marketplace tags; extend commit-guard to lint it | hook/tooling | S | — | library-engineer | Enables catalog organization before it grows further. |

### Wave 2 — core depth + first integration skills

| Item | Type | Effort | Depends on | Builder | Value note |
|------|------|--------|------------|---------|------------|
| `dependency-map` skill | skill | M | enriched pattern-diagram-design | librarian | Feeds pattern selection; high EA leverage. |
| `contract-analysis` skill (OpenAPI/WSDL/XSD) | skill | M | api-design (or standalone) | librarian | Breaking-change detection for APIC contracts. |
| `api-design` skill | skill | M | — | librarian | Core+integration bridge; pairs with postman + contract-analysis. |
| Enrich `develop` + `test` (scaffolds, fixtures, cookbooks) | skill | M | — | librarian | Core SDLC depth; shared security checklist with review. |
| `integration-team` composition | team | S | business-analyst agent | librarian | Standing EA workflow; needs the BA agent first. |
| `frontmatter/inventory linter` hook extension (version/model/twin-parity) | hook | S | category field (W1) | library-engineer | Keeps growing inventory honest. |
| **Commit-guard: depth-standard lint** (every `skills/<name>/` has `SKILL.md` **+ ≥1 companion resource**) | hook/tooling | S | first enriched skills (W1) | library-engineer | Future enforcement of the **mandated** depth standard (PO 2026-06-09); fails commit if a skill ships as a lone `SKILL.md`. Keep `.ps1`/`.js` twins in parity. |

### Wave 3 — EA specialization + remaining core

| Item | Type | Effort | Depends on | Builder | Value note |
|------|------|--------|------------|---------|------------|
| `cmdb-to-archimate` skill | skill | L | dependency-map | librarian | Lead EA differentiator; ties to PO's CMDB→Archimate project. |
| `message-flow-trace` skill | skill | M | pattern-diagram-design, dependency-map | librarian | DLQ/correlation tracing across APIC/ACE/MQ. |
| `requirements-elicitation` skill | skill | M | business-analyst agent | librarian | Realizes the BA discipline end-to-end. |
| `refactor` + `debug` skills | skill | M | — | librarian | Remaining core-SDLC depth. |
| Enrich `deploy` + `document` (template files) | skill | S | — | librarian | Finishes the progressive-disclosure sweep. |
| `test-on-edit` + `markdown/diagram lint` hooks | hook | M | hooks catalog pattern (W1) | library-engineer | Quality gates for the now-larger catalog. |
| MCP scoping decision (Postgres/OpenAPI/GitHub/custom APIC-MQ) | mcp | L | PO decision | architect + library-engineer | Deferred design; needs PO licensing/ownership answers. |

---

## 7b. Technology Knowledge Base — LOCKED decisions (PO 2026-06-11)

The library must scale to **~300 technologies** across the TCS platform taxonomy. The model below is research-backed (ecosystem **Pattern B+C**) and **locked** as of 2026-06-11. The foundation (architecture + template + skeleton) is built; the [`knowledge/`](../knowledge/README.md) tree is its home.

### The central-KB model

- **Skills stay technology-AGNOSTIC.** Workflows do not hard-code technology specifics.
- **Technology specifics live in a CENTRAL hierarchical knowledge base** at `knowledge/<group>/<platform>/<technology>.md`, referenced by role agents and skills via relative links — **NOT** per-technology agents, **NOT** per-skill duplication.
- **Why central at 300-technology scale:** write-once / reference-many. Per-skill bundling would duplicate the same facts across N skills; per-technology agents would mean ~300 agents. Both are unmaintainable. See the [KB architecture](../knowledge/README.md).

### Per-platform team granularity (~16 teams, LATER)

Platform teams come **after** the KB matures (Phase 3, below). Granularity is **per-platform** — ~16 teams, one per platform in the taxonomy:

- **customer-journey:** digital-platforms, sf-mce-mcp, gcc
- **business-capability:** sf-sc, fsm, idit, sap, hr, camping-care
- **data-capability:** business-saas, business-intelligence, big-data
- **core-it:** collaboration, doc-mgt, azure-saas, internal-developer-platform

These are **not** created now (no team files authored in the foundation pass).

### 4-phase rollout

| Phase | Scope | Status |
|-------|-------|--------|
| **Phase 0** | KB architecture + pack template (`knowledge/README.md`, `knowledge/_TEMPLATE.md`) | ✅ done (2026-06-11) |
| **Phase 1** | Empty skeleton tree to **platform level** (group + platform folders, platform `README.md` indexes with seed component lists) | ✅ done (2026-06-11) |
| **Phase 2** | **Pilot one platform** — author real technology packs for a single platform to validate the template and depth standard end-to-end | pending |
| **Phase 3** | **Scale** — roll out packs across platforms; **create-on-first-use** (a pack is authored when an agent first needs it); a **scaffolding skill** to generate a conformant pack from `_TEMPLATE.md`; create the ~16 per-platform teams | pending |

### Scale-governance note

The CLAUDE.md **Self-Maintaining Inventory MUST NOT enumerate technology packs** — it tracks only agents/skills/teams. The KB is instead governed by **(a)** a **generated KB index** (script walks the tree, rolls up `status`/`owner`/`last-reviewed`) and **(b)** a **template-conformance lint** — a planned **extension to the commit-guard owned by the library-engineer**, checking each pack's required frontmatter + mandated section headings. The lint is **deferred, NOT implemented now**; the current commit-guard still checks only agent/skill/team counts + AGENT/SKILL frontmatter and is untouched by the foundation.

---

## 8. Open Questions for the PO

1. ~~**Confirm the `business-analyst` agent.**~~ **RESOLVED (PO 2026-06-09): APPROVED.** BA is a distinct discipline from the PO-assistant; added to Layer 2 as Approved. (The `integration-team` that depends on it is likewise **APPROVED 2026-06-09** — see Layer 1.)
2. **Depth standard.** ~~(Was implicit in Layer 3.)~~ **RESOLVED (PO 2026-06-09): MANDATED as a library rule** — "every skill must bundle at least one loadable artifact (template / checklist / scaffold) — progressive disclosure." Applies to new skills and ENRICH items; a future commit-guard check will enforce it (Wave-2 backlog).
3. **Single plugin vs sub-bundles.** Do you accept staying single-plugin (tag/category-organized), or do you foresee an external consumer who needs core-SDLC *without* the EA layer? (Layer 0 recommends single.)
4. **Highest-priority integration skills.** Of `dependency-map`, `contract-analysis`, `cmdb-to-archimate`, `message-flow-trace` — which one or two deliver the most value to your current work, so we sequence them earliest?
5. **BA Write boundary.** Should `business-analyst` be read-only (delegating artifact writes to the documentarian, like the PO), or get scoped `Write` under `docs/requirements/`? (Layer 4 defaults read-only.)
6. **Hooks: opt-in default set.** Which proposed hooks (secret-scan, linter extension, depth-standard lint, test-on-edit, md/diagram lint) should ship as a *recommended default* in `templates/settings.json` vs purely opt-in extras?
7. **Wave 1 sign-off.** Approve the Wave-1 set as the first build train (one plugin minor bump), or trim/reorder it before we apply anything?
8. ~~**Technology knowledge: per-skill, per-tech-agent, or central KB?**~~ **RESOLVED (PO 2026-06-11): central hierarchical KB** (Pattern B+C) — skills stay agnostic; specifics live in `knowledge/<group>/<platform>/<technology>.md`, referenced by role agents/skills. See §7b.
9. ~~**Scale to ~300 technologies — how to govern without bloating the inventory?**~~ **RESOLVED (PO 2026-06-11):** the Self-Maintaining Inventory does **not** enumerate packs; governance is a generated KB index + a deferred commit-guard template-conformance lint (library-engineer). See §7b.
10. ~~**Platform team granularity.**~~ **RESOLVED (PO 2026-06-11): per-platform (~16 teams), created LATER** (Phase 3), not in the foundation. See §7b.

---

*Reminder: this document is a RECOMMEND-mode artifact. Nothing in the inventory, agents, skills, teams, or hooks has been changed. On approval, the repo-improvement-team applies the agreed items, syncs the CLAUDE.md inventory, refreshes Confluence, and the human commits.*
