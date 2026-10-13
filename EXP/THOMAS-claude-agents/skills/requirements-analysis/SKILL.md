---
name: requirements-analysis
version: 1.0.0
type: methodological
category: business-analysis
standards:
  - IEEE 830 — Software Requirements Specification
  - BABOK v3 (IIBA)
  - MoSCoW prioritisation
description: >
  Elicit, analyse, document, and validate software requirements. Produces a
  Requirements Specification (BRD/FRS) with uniquely identified, traceable,
  testable requirements. Use when starting a new feature, clarifying scope, or
  formalising stakeholder needs before architecture or development begins.
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, TodoWrite, AskUserQuestion, mcp__claude_ai_Atlassian__*
---

# /requirements-analysis — Requirements Elicitation & Specification

## Step 1: Elicit Requirements

Gather inputs from available sources:
- Existing Jira epics/stories (via Atlassian MCP)
- Stakeholder interviews (use AskUserQuestion for clarification)
- Business process documents, regulations, existing system documentation
- Competitive benchmarks or reference implementations

For each source, note: stakeholder name · source type · date · confidence level.

## Step 2: Classify Requirements

| Type | Description | Example |
|---|---|---|
| Functional | What the system SHALL do | "The API shall return a 401 for unauthenticated requests" |
| Non-Functional | How the system performs | "Response time < 500 ms at p95" |
| Constraint | Fixed limits | "Must run on Azure Switzerland North" |
| Assumption | Treated as true without proof | "Users have internet access" |

## Step 3: Write Requirements (IEEE 830 structure)

Each functional requirement:
```
**ID:** FR-NNNN
**Title:** <verb phrase>
**Description:** The system SHALL <capability>.
**Acceptance Criteria:**
- Given <context>, When <action>, Then <observable outcome>
**Priority:** Must / Should / Could / Won't (MoSCoW)
**Traces to:** <business objective or epic ID>
**Source:** <stakeholder / document>
```

## Step 4: Validate Requirements

Apply SMART checks — each requirement must be:
- **S**pecific: unambiguous, one interpretation
- **M**easurable: testable, has acceptance criteria
- **A**chievable: technically feasible
- **R**elevant: traces to a business objective
- **T**ime-bound: in scope for the current release (or explicitly deferred)

Flag requirements that fail SMART with a `[NEEDS CLARIFICATION]` tag.

## Step 5: Output

Write the specification to `docs/requirements/{slug}.md` following the `requirements-specification` artefact template. Update the Jira epic with a link to the spec.

## Quality Gate

- [ ] All requirements have unique IDs (FR-NNNN, NFR-NNNN, CON-NNNN)
- [ ] Every FR has at least one Given/When/Then acceptance criterion
- [ ] MoSCoW priority assigned to each requirement
- [ ] No solution bias ("what" not "how")
- [ ] Traceability to business objective confirmed
