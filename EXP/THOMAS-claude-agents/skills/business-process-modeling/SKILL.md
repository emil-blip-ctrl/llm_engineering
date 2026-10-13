---
name: business-process-modeling
version: 1.0.0
type: methodological
category: business-analysis
standards:
  - BPMN 2.0 (OMG)
  - BABOK v3 — Business Process Analysis technique
description: >
  Model business processes using BPMN 2.0 notation to capture current-state (AS-IS)
  or future-state (TO-BE) workflows. Use when stakeholders need to understand a
  process before automating it, or when analysing process inefficiencies.
allowed-tools: Read, Write, Edit, Glob, WebSearch, WebFetch, TodoWrite
---

# /business-process-modeling — BPMN Process Modeling

## Step 1: Define Process Scope

State clearly:
- **Process name** (verb + noun: "Process Insurance Claim")
- **Trigger** (what starts the process)
- **End state** (what a successful completion looks like)
- **Participants / Swim lanes** (roles or systems involved)
- **AS-IS or TO-BE** (current state or desired future state)

## Step 2: Identify Process Elements

| BPMN Element | Symbol | When to use |
|---|---|---|
| Start Event | ○ | Process trigger |
| End Event | ◉ | Process completion |
| Task | □ | An atomic unit of work |
| User Task | 👤□ | Human performs the work |
| Service Task | ⚙□ | Automated / system action |
| Gateway (XOR) | ◇ | Exclusive decision |
| Gateway (AND) | ◆ | Parallel split or join |
| Sub-Process | ⊞ | Collapsible complex activity |
| Message Flow | - - → | Communication between pools |

## Step 3: Draw the Process (Mermaid)

Use Mermaid flowchart as a lightweight BPMN approximation:

```mermaid
flowchart LR
  Start([Start: Request received]) --> Validate[Validate request]
  Validate --> Decision{Valid?}
  Decision -- Yes --> Process[Process request]
  Decision -- No --> Reject[Send rejection]
  Process --> Notify[Notify requester]
  Notify --> End([End: Request closed])
  Reject --> End
```

## Step 4: Annotate Key Points

For each decision gateway, document:
- Decision rule (business rule that drives the branch)
- Data needed to evaluate the rule

For each task, document:
- Actor (human role or system)
- Estimated cycle time (if known)
- Systems/tools used

## Step 5: Validate with Stakeholders

- [ ] All swim lanes / actors identified
- [ ] Every path from Start to End is complete (no dead ends)
- [ ] Business rules at gateways are explicit
- [ ] Exceptions and error paths documented
- [ ] Stakeholder sign-off obtained before progressing to requirements
