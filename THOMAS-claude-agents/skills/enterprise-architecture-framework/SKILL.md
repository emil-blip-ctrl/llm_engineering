---
name: enterprise-architecture-framework
version: 1.0.0
type: methodological
category: architecture
standards:
  - TOGAF 9.2 (The Open Group)
  - ArchiMate 3.1 (The Open Group)
  - ISO/IEC 42010:2011 — Systems and Software Engineering — Architecture Description
  - Zachman Framework
description: >
  Apply enterprise architecture discipline: scope domains (Business/Application/Data/
  Technology), produce architecture views, select the right ArchiMate elements, and
  manage governance gates. Use when designing system-wide structure, reviewing an
  architectural proposal, or mapping a solution to the enterprise landscape.
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, TodoWrite
---

# /enterprise-architecture-framework — EA Discipline

## Step 1: Scope the Architecture

Identify which TOGAF Architecture Domains are in play:
- **Business** — capabilities, processes, actors, roles
- **Data** — data entities, flows, storage, classification
- **Application** — application components, services, interfaces
- **Technology** — infrastructure, platforms, cloud services, networks

Record scope in a brief Architecture Scope Statement (one paragraph).

→ **Action:** `Read` the project CLAUDE.md and any existing `docs/architecture/` files to extract the current system description.

## Step 2: Identify Stakeholders and Concerns

List stakeholders and their primary concern per ISO/IEC 42010:
- Business Owner → capability coverage, cost
- Developer → component boundaries, interfaces
- Operations → deployment, monitoring, SLA
- Security → threat surface, data classification

## Step 3: Select Architecture Viewpoints

Choose the minimum set of views to address each concern:

| Concern | Viewpoint | ArchiMate layer |
|---|---|---|
| Business capability | Business layer | Capability, Role, Process |
| System context | Application + Technology | Component, Node, Network |
| Data flow | Application + Data | DataObject, Flow |
| Deployment | Technology | Node, Device, SystemSoftware |
| Motivation | Motivation | Goal, Driver, Constraint |

→ **Action:** `Write` a summary table to `docs/architecture/architecture-scope.md` listing selected viewpoints and their stakeholder rationale.

## Step 4: Produce Architecture Description

For each selected view:
1. Identify elements (use ArchiMate element types)
2. Define relationships (Serving, Flow, Composition, Realisation, Assignment)
3. Validate: no orphaned elements, relationships are typed correctly, layers respected
4. Cross-reference to the `target-architecture` artefact if a `.archimate` file is in scope

→ **Action:** For each view, invoke the `pattern-diagram-design` skill (for integration views) or `archimate-generation` skill (for ArchiMate views) to produce the diagram artefact.

## Step 5: Governance Gate

Before finalising, run this checklist and write results to `docs/architecture/architecture-scope.md`:

- [ ] All stakeholder concerns addressed by at least one view
- [ ] Decisions recorded as ADRs — invoke `architecture-decision-records` skill for each
- [ ] Architecture scope statement written to `docs/architecture/architecture-scope.md`
- [ ] Architecture Description reviewed by a peer architect
- [ ] Deviations from enterprise standards documented with rationale

→ **Action:** `Write` the completed checklist with date stamp to `docs/architecture/governance-gate.md`.
