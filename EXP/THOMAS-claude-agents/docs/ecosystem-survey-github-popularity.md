# Claude Code Ecosystem Survey — GitHub Popularity & Adoption Shortlist

**Date:** 2026-06-09

**Purpose & methodology:** A landscape survey of the public Claude Code ecosystem (agents, skills, hooks, MCP servers) across our four domains of interest — Development, Business Analysis (BA), Architecture, Integration — ranked to inform what this library should adopt, reference, or skip. Popularity is ranked primarily by GitHub **stars**, with **forks/recency** as secondary signals; star counts are approximate and recency is "last commit" / latest release as of the date above.

---

## Part A — Landscape Survey

### Agents

| Name | Repo URL | ~Stars | Last commit | Domain(s) | Purpose |
|------|----------|--------|-------------|-----------|---------|
| VoltAgent/awesome-claude-code-subagents | https://github.com/VoltAgent/awesome-claude-code-subagents | ~20.5k | 2026 | Dev / Arch / Integration | 100+ subagents incl. backend, api, cloud-architect (MIT) |
| wshobson/agents | https://github.com/wshobson/agents | ~17k | 2026 | Dev / Arch / Integration | 76+ subagents incl. cloud-architect, api-designer, backend-architect (MIT) |
| vijaythecoder/awesome-claude-agents | https://github.com/vijaythecoder/awesome-claude-agents | ~4k | 2025 | Dev / Arch | 24-agent orchestrated dev team |
| 0xfurai/claude-code-subagents | https://github.com/0xfurai/claude-code-subagents | ~1k | 2025 | Dev / Integration | 100+ dev/API subagents |
| rahulvrane/awesome-claude-agents | https://github.com/rahulvrane/awesome-claude-agents | ~0.5k | 2025 | Dev / Arch | Curated index |

### Skills

| Name | Repo URL | ~Stars | Last commit | Domain(s) | Purpose |
|------|----------|--------|-------------|-----------|---------|
| anthropics/skills | https://github.com/anthropics/skills | ~141k (whole repo) | 2026 | Dev / Arch | Official reference skills (MCP-gen, testing, docs) |
| VoltAgent/awesome-agent-skills | https://github.com/VoltAgent/awesome-agent-skills | ~22k | 2026 | Dev / Arch / Integration | 1000+ skills incl. api-design, arch, security (MIT) |
| hesreallyhim/awesome-claude-code | https://github.com/hesreallyhim/awesome-claude-code | ~12k | 2026 | Dev / Arch | Canonical curated index |
| alirezarezvani/claude-skills | https://github.com/alirezarezvani/claude-skills | ~5.2k | 2026 | Dev / BA / Integration | 330+ skills incl. product/BA |
| rohitg00/awesome-claude-code-toolkit | https://github.com/rohitg00/awesome-claude-code-toolkit | ~2.4k | 2026 | Dev / Arch / BA | 135 agents / 35 skills incl. PM, Architect, DevOps |
| travisvn/awesome-claude-skills | https://github.com/travisvn/awesome-claude-skills | ~0.8k | 2025 | Dev / BA | Workflow skills list |

### Hooks

| Name | Repo URL | ~Stars | Last commit | Domain(s) | Purpose |
|------|----------|--------|-------------|-----------|---------|
| hesreallyhim/awesome-claude-code (hooks section) | https://github.com/hesreallyhim/awesome-claude-code | ~12k | 2026 | All | Canonical curated hooks list |
| disler/claude-code-hooks-mastery | https://github.com/disler/claude-code-hooks-mastery | ~3k | 2026 | Dev / Arch | Reference for all 13 lifecycle hooks |
| rohitg00/awesome-claude-code-toolkit | https://github.com/rohitg00/awesome-claude-code-toolkit | ~1k | 2026 | All | Bundled hooks + MCP + rules |
| claude-code-prompt-improver | https://github.com/cco-ai/claude-code-prompt-improver | ~1k | 2026 | Dev / BA | UserPromptSubmit prompt rewriter |
| disler/claude-code-hooks-multi-agent-observability | https://github.com/disler/claude-code-hooks-multi-agent-observability | ~0.9k | 2026 | Dev / Integration | Real-time hook-event monitoring |
| JessyTsui/Claude-Code-Remote | https://github.com/JessyTsui/Claude-Code-Remote | ~0.9k | 2026 | Dev | Stop-hook notify on completion |

*Note: most hooks live inside collections; few are standalone.*

### MCP Servers (Integration / Architecture weighted)

| Name | Repo URL | ~Stars | Last commit | Domain(s) | Purpose |
|------|----------|--------|-------------|-----------|---------|
| modelcontextprotocol/servers | https://github.com/modelcontextprotocol/servers | ~60k+ | 2026 | All | Official refs (fs, fetch, memory) — MIT |
| github/github-mcp-server | https://github.com/github/github-mcp-server | ~20k+ | 2026 | Dev / Integration | Official GitHub API — MIT |
| googleapis/genai-toolbox | https://github.com/googleapis/genai-toolbox | ~15k | 2026-06 | Integration (DB) | Secure multi-DB tools — Apache-2.0 |
| idosal/git-mcp | https://github.com/idosal/git-mcp | ~8.1k | 2026-05 | Dev / Arch | Connect to any GitHub repo docs — Apache-2.0 |
| sooperset/mcp-atlassian | https://github.com/sooperset/mcp-atlassian | ~5.3k | 2026 | BA / Arch | Jira + Confluence — MIT |
| crystaldba/postgres-mcp | https://github.com/crystaldba/postgres-mcp | ~2.8k | 2026-05 | Integration (DB) | RW + performance analysis — MIT |
| supabase-community/supabase-mcp | https://github.com/supabase-community/supabase-mcp | ~2.7k | 2026-05 | Integration (DB) | Supabase tooling — Apache-2.0 |
| janwilmake/openapi-mcp-server | https://github.com/janwilmake/openapi-mcp-server | ~0.9k | 2026 | Integration (API) | Wrap any REST API via OpenAPI — MIT |
| docker/hub-mcp | https://github.com/docker/hub-mcp | ~150 | 2026 | Integration | Official Docker Hub — Apache-2.0 |

### Ecosystem observations

- **The ecosystem skews heavily Dev + Architecture.** Agents and skills cluster around backend/cloud-architect/api-designer roles; the largest collections (VoltAgent, wshobson) are dev-centric.
- **BA is under-served.** Only a handful of collections (alirezarezvani, rohitg00) surface product/PM/BA roles, and none offer a coherent BA *discipline* — requirements elicitation, backlog shaping, stakeholder analysis — as a first-class agent or skill set.
- **Middleware / iPaaS integration is a gap.** MCP coverage is rich for **databases and generic REST/API** (genai-toolbox, postgres-mcp, supabase, openapi-mcp) but there is **no popular MCP for message brokers or iPaaS** — Kafka, IBM MQ, RabbitMQ, MuleSoft, APIC/ACE. Integration "leadership" in the ecosystem means data/API plumbing, not enterprise middleware.
- **Hooks rarely ship standalone.** Reusable hook logic mostly lives inside larger collections; observability (disler) is the clearest standalone value.
- **Curated indexes dominate the top of the star charts.** Much of the "popularity" is meta — lists pointing at other repos — so raw stars overstate directly reusable assets.

---

## Part B — Adoption Shortlist (mapped to our inventory)

Our current inventory: agents `architect, developer, tester, devops, documentarian, product-owner-assistant, librarian, library-engineer`; skills `develop, test, deploy, review, document, security-audit, postman-collection-generator, publish-confluence, pattern-diagram-design`; teams `feature-team, release-team, full-team, repo-improvement-team`. We already use **mcp-atlassian** in `product-owner-assistant`.

| Candidate | Why adopt | Maps to / gap in our lib | Recommendation |
|-----------|-----------|--------------------------|----------------|
| anthropics/skills | Official skill conventions & MCP-generation patterns — authoritative baseline | Reference for our SKILL.md authoring + `skills/` shape | **Reference-only — adopted 2026-06-09; cited in SKILL-AUTHORING.md (pinned ref `c30d329`)** |
| disler/claude-code-hooks-multi-agent-observability | Real-time visibility into our multi-agent team runs (we already have checkpoints + progress reporting, but no live event view) | New capability; complements `.claude/hooks/` and team protocols — no equivalent in our lib | **Adopt (pilot)** |
| googleapis/genai-toolbox | Secure, governed multi-DB access — Apache-2.0, enterprise-friendly licensing | Fills an Integration(DB) gap; no DB-access tooling in our lib today | **Adopt (eval)** |
| janwilmake/openapi-mcp-server | Wrap any REST API from an OpenAPI spec — directly relevant to APIC/ACE API surfaces | Complements `postman-collection-generator` + `architect`; we have no live-API MCP | **Adopt (eval)** |
| sooperset/mcp-atlassian | Jira + Confluence tools | **Already adopted** in `product-owner-assistant`; validates our BA/publish direction | **Reference-only** (confirm version pin) |
| disler/claude-code-hooks-mastery | Worked examples of all 13 lifecycle hooks | Hardening reference for our commit-guard + UserPromptSubmit orchestration hooks | **Reference-only** |
| VoltAgent/awesome-claude-code-subagents | Breadth check for agent role coverage (cloud-architect, api-designer) | Benchmark our 8 agents against; our roles are deliberately enterprise-integration scoped | **Reference-only** |
| wshobson/agents | Same — large curated agent set incl. backend-architect | Benchmark only; our `architect` is APIC/ACE/MQ-specialised, not generic cloud | **Skip (adopt none directly)** |
| openapi/REST generic dev subagents (0xfurai, vijaythecoder) | Generic dev-team agents | Overlap with `developer`/`tester`/`feature-team`; no enterprise-integration depth | **Skip** |
| message-broker / iPaaS MCP (Kafka/MQ/MuleSoft) | Would be highest-value Integration adoption | **No mature public option exists** — this is our strongest differentiator to potentially build | **Skip (none viable) — candidate to build** |

### Where we are strong vs where the ecosystem leads

- **We lead:** enterprise integration depth (APIC / ACE / IBM MQ via `architect` + `pattern-diagram-design`), a coherent **BA capability** (PO-assistant + architect + Atlassian/Confluence publishing), and a governed self-maintaining library with commit-guard enforcement. The ecosystem has nothing comparable for middleware patterns or governed library upkeep.
- **Ecosystem leads:** sheer **breadth of MCP DB/API servers** (genai-toolbox, postgres-mcp, openapi-mcp), **hook observability** tooling, and the volume/variety of generic dev subagents and skills.

---

## Open Questions for the PO

- **Licensing posture:** are Apache-2.0 / MIT third-party MCP servers acceptable to embed or only to reference, given enterprise (TCS) distribution constraints?
- **Build vs. wait:** the message-broker / iPaaS MCP gap (Kafka, MQ, MuleSoft, APIC/ACE) is unfilled publicly — do we invest in building one as a differentiator, or hold until a credible community option appears?
- **Hook observability scope:** is live multi-agent event monitoring worth a dependency, or is our existing checkpoint + progress-reporting protocol sufficient for now?
- **DB / API MCP ownership:** if we adopt genai-toolbox or openapi-mcp-server, which agent owns them (`architect`, `developer`, or a new role) and what tool-restriction guardrails apply?
- **Reference vs. vendor:** for benchmark repos (VoltAgent, wshobson, anthropics/skills), do we want a tracked "ecosystem watch" doc, or one-off comparisons only?

---

## Part C — Ecosystem Management & Governance

**Date:** 2026-06-09 — **Scope:** how the broader Claude Code / MCP ecosystem *manages* and *governs* agents, skills, plugins, and MCP servers — distribution & packaging, then governance/security/lifecycle — closing with an honest self-benchmark of this library against those practices. Parts A/B surveyed *what exists*; Part C surveys *how it is shipped, secured, and kept trustworthy*.

### C.1 Distribution & packaging landscape

- **Plugins are the installable/pinnable unit, marketplaces are catalogs.** A [`marketplace.json`](https://code.claude.com/docs/en/plugin-marketplaces) is a *catalog* that points at plugins (each carrying its own `.claude-plugin/plugin.json` with a required `version`); the marketplace source and the plugin source are independent, so one catalog can reference many repos at different refs. Anthropic ships a `claude-plugins-official` marketplace by default.
- **Pinning granularity is converging on SHA for reproducibility.** Plugins can be pinned by branch or tag (`@ref` / `#ref`); plugin *sources* additionally accept an **exact commit SHA**, which is the recommended posture for reproducible/prod installs. Native **per-marketplace auto-update** has existed since CC v2.0.70 — reducing the need for bespoke updater scripts.
- **MCP discovery is maturing into real registries.** The official [`registry.modelcontextprotocol.io`](https://registry.modelcontextprotocol.io) (API-first, preview Sept 2025) anchors a tier of human directories: Glama (~21k servers), mcp.so (~20k), PulseMCP (~11.8k, hand-reviewed), Smithery (~7k, app-store UX + hosted remote), and the [Docker MCP Catalog](https://docs.docker.com/ai/mcp-catalog-and-toolkit/catalog/) (verified/curated entries plus private org catalogs).
- **Two library distribution patterns dominate.** (a) *Curated `awesome-*` lists* (e.g. VoltAgent's ~1000+ skills) — discovery, not install; (b) *package-manager-native* tooling that maps skills onto npm: [`skillpm`](https://github.com/sbroenne/skillpm) and [`skills-npm`](https://github.com/antfu/skills-npm) give skills `package.json` + lockfiles + semver + workspaces, symlinking `node_modules` → skills.
- **Biggest trend:** the ecosystem is **treating skills/plugins as real software packages** — semver + lockfiles + SHA-pinned registries — steadily replacing ad-hoc copy/symlink scripts. The remaining core install trade-off is symlink/junction (track HEAD) vs copy-snapshot (freeze).

| Platform / Tool | URL | Role | Maturity signal |
|-----------------|-----|------|-----------------|
| Claude Code plugin marketplaces | https://code.claude.com/docs/en/plugin-marketplaces | Native catalog + install/pin; per-marketplace auto-update | Native, official; SHA pinning supported |
| Official MCP Registry | https://registry.modelcontextprotocol.io | API-first canonical MCP discovery | Preview (Sept 2025), governance-oriented |
| Docker MCP Catalog | https://docs.docker.com/ai/mcp-catalog-and-toolkit/catalog/ | Verified/curated MCP catalog + org catalogs | Vendor-backed, "verified" tier |
| skillpm | https://github.com/sbroenne/skillpm | Skills as npm packages (semver + lockfile) | Emerging community tooling |
| skills-npm | https://github.com/antfu/skills-npm | Skills → npm workspaces, symlinked | Emerging (high-profile author) |
| Glama / mcp.so / PulseMCP / Smithery | https://glama.ai/mcp/servers · https://mcp.so · https://www.pulsemcp.com · https://smithery.ai | Human MCP directories (discovery, some hosting) | High volume; review rigor varies |

### C.2 Governance, security & lifecycle landscape

- **Permissions are layered and deny-first.** [`settings.json`](https://code.claude.com/docs/en/settings) uses `allow`/`deny`/`ask` arrays evaluated **deny > allow > ask**, across scopes **enterprise (managed) > user > project > local**. Least-privilege practice: minimal `allowedTools` + `permissionMode`, with `deny` rules (e.g. `Read(.env*)`) holding even under bypass; MCP access is scoped per-server.
- **Validation is shifting from schema linting to evals.** Frontmatter/schema lint catches missing `name`/`description` but not *output quality*. The field is moving toward **LLM-as-judge evals**: [Promptfoo](https://www.promptfoo.dev) (used by Anthropic/OpenAI) runs declarative evals + red-team suites inside CI/PRs. `PreToolUse` hooks as commit guards (our repo's pattern) sit alongside this.
- **Security threat model is dominated by the "lethal trifecta."** Willison's framing — [private data + untrusted content + an exfiltration vector](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) — is the reference risk. With ~8000 exposed MCP servers in the wild, tool-poisoning and zero-click RCE via indirect prompt injection are live. Defenses: outgoing-proxy/DLP, capability pinning, sandboxing, and **MCP gateways as chokepoints** (e.g. [mcp-gateway-registry](https://github.com/agentic-community/mcp-gateway-registry)).
- **Enterprise governance is real but supply-chain trust is weak.** `managed-settings.json` (via MDM/registry) plus `allowManagedMcpServersOnly` + `strictKnownMarketplaces` lock down the supply chain; SCIM, RBAC, a Compliance API, IP allowlists, and centralized-gateway audit exist. NSA's MCP CSI (May 2026) adds public guidance.
- **Lifecycle is formalizing; provenance is not.** The MCP spec defines an Active → Deprecated → Removed path (≥12-month notice) with a conformance suite, and the official registry is emerging for governed discovery. **Biggest gap:** there is **no end-to-end signing/provenance** for MCP servers, skills, or plugins — trust rests on registry reputation, leaving *prompt-injection-via-package* the largest unmitigated risk.

| Tool / Standard | URL | Role | Maturity signal |
|-----------------|-----|------|-----------------|
| Claude Code settings & permissions | https://code.claude.com/docs/en/settings | allow/deny/ask, managed-settings, scope precedence | Native, enterprise-ready |
| Promptfoo | https://www.promptfoo.dev | Declarative LLM evals + red-team in CI/PRs | Production, vendor-adopted |
| "The lethal trifecta" (Willison) | https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/ | Canonical agent-security threat model | Widely cited reference |
| MCP gateway registry | https://github.com/agentic-community/mcp-gateway-registry | Gateway chokepoint + governance for MCP | Emerging pattern |
| Official MCP Registry (lifecycle) | https://registry.modelcontextprotocol.io | Deprecation lifecycle + conformance | Preview; signing still absent |

### C.3 Self-benchmark — this library vs ecosystem practice

Honest scorecard of our current management/governance model (verified against `CLAUDE.md`, `.claude-plugin/`, `templates/`, and `.claude/hooks/`).

| Dimension | Ecosystem best practice | Our library today | Status | Recommended action |
|-----------|-------------------------|-------------------|--------|--------------------|
| Plugin / marketplace packaging | `plugin.json` + `marketplace.json` catalog, auto-discovered dirs | Have both: `agentic-claude` plugin + `agentic-claude-lib` marketplace, auto-discovers `agents/`/`skills/`/`commands/` | **Strong** | Keep; add a `commands/` shim only if needed |
| Version pinning (tag vs SHA) | Tag for releases, **exact SHA** for reproducible/prod installs | Git **tag** pin only (`v1.2.1`); no SHA option documented | **Adequate** | Document a SHA-pin recipe for prod consumers (S) |
| Install tooling / lockfile | Reuse npm/uv + lockfiles; native CC auto-update | Bespoke PowerShell (`install`/`setup`/`update.ps1`); **no lockfile**, Windows-first | **Gap** | Lean on native plugin auto-update; add cross-platform path (M) |
| Frontmatter validation | Schema/frontmatter lint in CI | Commit-guard hook lints `name`/`description` + inventory sync | **Strong** | Keep; extend to `version:`/`model:` field checks (S) |
| Automated evals / testing | LLM-as-judge evals (Promptfoo) in PRs | **None** — no behavioral tests of agents/skills | **Gap** | Pilot Promptfoo evals for 2–3 skills in CI (L) |
| Permission / tool-restriction | Least-privilege `allowedTools`, deny-first | Per-agent curated tool lists by role; project-scoped memory | **Strong** | Add explicit `deny(Read(.env*))` example to template (S) |
| Commit governance | Hooks/CI gate merges | `PreToolUse` commit-guard (`.ps1` + `.js` twin); repo-improvement-team only; human commits | **Strong** | Keep; ensure twin parity stays enforced |
| Signing / provenance | (Ecosystem gap — none mature) | None | **Gap (shared)** | Watch; adopt when a standard lands — not worth building now |
| Enterprise managed-settings | `managed-settings.json`, `strictKnownMarketplaces` | No managed-settings example shipped | **Gap** | Add a `templates/managed-settings.json` example for TCS (M) |
| MCP supply-chain controls | Gateways, `allowManagedMcpServersOnly`, curated catalogs | Only `mcp-atlassian` used; no gateway/allowlist guidance | **Adequate** | Document MCP allowlist + pin posture for consumers (S) |

### C.4 Prioritized recommendations

**Quick wins (do soon)**

- **[S] Document a SHA-pin recipe** for reproducible/prod consumers alongside the existing tag pin — closes the highest-value packaging gap at near-zero cost.
- **[S] Ship a least-privilege `deny` example** (`Read(.env*)`, secrets) in `templates/settings.json` so consuming projects inherit deny-first defaults.
- **[S] Document an MCP allowlist + pin posture** (and reference `strictKnownMarketplaces`) so consumers know the supply-chain stance, even though we ship few MCP servers.
- **[S] Extend the commit-guard** to lint `version:`/`model:` frontmatter fields, not just `name`/`description` — cheap reinforcement of an already-Strong dimension.

**Strategic (plan/scope)**

- **[M] Add a `templates/managed-settings.json` example** targeted at TCS enterprise rollout (MDM/registry deployment) — turns an outright Gap into a differentiator for regulated adoption.
- **[M] Add a cross-platform install path** (or formally lean on native plugin auto-update and de-emphasize the PowerShell updater) to remove the Windows-first constraint.
- **[L] Pilot Promptfoo evals** for 2–3 skills in CI — the single biggest maturity gap vs the ecosystem; start small (one skill, golden outputs) before generalizing.
- **[Watch] Signing/provenance** — a shared ecosystem gap with no mature standard; do **not** build bespoke. Track the official MCP Registry and adopt when verification ships.
