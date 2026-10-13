---
name: architecture-decision-records
version: 1.0.0
type: methodological
category: architecture
standards:
  - Nygard ADR format (cognitect.com, 2011)
  - TOGAF Architecture Decision artefact
  - ISO/IEC 42010:2011 — Architecture Rationale
description: >
  Write, review, and maintain Architecture Decision Records (ADRs) following the
  Nygard format. Use when a significant architectural decision is made, revisited,
  or superseded. Produces artefacts stored in docs/architecture/decisions/.
allowed-tools: Read, Write, Edit, Grep, Glob, TodoWrite
---

# /architecture-decision-records — ADR Authoring

## Step 1: Decide if an ADR is needed

Write an ADR when:
- A technology, pattern, or structural choice affects more than one component
- The decision has long-term consequences (hard to reverse)
- Stakeholders asked "why did we choose X?"
- You are overriding a previous ADR

Do NOT write an ADR for implementation details (variable names, minor refactors).

## Step 2: Number and Title

- Filename: `docs/architecture/decisions/NNNN-<verb-phrase>.md`
  (e.g., `0001-use-ibm-apic-as-api-gateway.md`)
- Title: a present-tense verb phrase — "Use X", "Adopt Y", "Replace Z with W"

## Step 3: Write the ADR (Nygard format)

```markdown
# NNNN — <Title>

**Date:** YYYY-MM-DD
**Status:** Draft | Proposed | Accepted | Deprecated | Superseded by [NNNN]

## Context

<Describe the forces at play: technical, business, team, regulatory.
What problem are we solving? What constraints exist?>

## Considered Options

1. **Option A — <name>**: <one-line description>
2. **Option B — <name>**: <one-line description>
3. **Option C — <name>**: <one-line description>

## Decision

We will adopt **Option X** because <rationale>.

## Consequences

**Positive:**
- <benefit 1>

**Negative / Trade-offs:**
- <cost or risk 1>

**Neutral:**
- <side effect that is neither good nor bad>
```

## Step 4: Lifecycle

- Set status to `Proposed` and request architect peer review
- After review, product-owner-assistant promotes to `Accepted`
- When superseded: set status to `Superseded by [NNNN]` and add a link

## Step 5: Quality Gate Checklist

- [ ] Title is a verb phrase
- [ ] Context explains the forces (not just the solution)
- [ ] At least 2 alternatives listed
- [ ] Decision states the chosen option AND the rationale
- [ ] Consequences covers both positives and negatives
- [ ] Stored under `docs/architecture/decisions/NNNN-*.md`
