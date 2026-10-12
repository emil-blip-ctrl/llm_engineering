---
name: integration-patterns
version: 1.0.0
type: methodological
category: architecture
standards:
  - Enterprise Integration Patterns (Hohpe & Woolf, 2003)
  - ARCHI integration pattern catalog (TCS)
  - IBM Integration Bus / ACE pattern library
description: >
  Identify, select, and document integration patterns for system-to-system
  communication. Covers messaging, routing, transformation, and reliability patterns
  aligned to EIP vocabulary. Use when designing how two or more systems exchange data,
  or when documenting an existing integration for review.
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, TodoWrite
---

# /integration-patterns — Integration Pattern Selection

## Step 1: Characterise the Integration Need

Answer these questions before selecting a pattern:

| Question | Drives |
|---|---|
| Sync or async? | Request-Reply vs Message Channel |
| One sender or many? | Point-to-Point vs Publish-Subscribe |
| Transformation needed? | Message Translator |
| Multiple recipients? | Splitter / Aggregator |
| Reliability required? | Dead Letter Channel, Guaranteed Delivery |
| Retry on failure? | Retry / Circuit Breaker |

## Step 2: Select Pattern(s) from EIP Catalog

Core patterns:
- **Message Channel** — decouples sender and receiver
- **Request-Reply** — synchronous call with correlation
- **Publish-Subscribe** — fan-out to multiple consumers
- **Message Router** — content-based routing
- **Message Translator** — payload transformation
- **Splitter / Aggregator** — split a message, process parts, recombine
- **Dead Letter Channel** — undeliverable message handling
- **Idempotent Receiver** — safe re-delivery handling

## Step 3: Document the Pattern

For each integration point, produce a pattern entry in `docs/architecture/integration-patterns.md`:

```
### <Pattern Name>: <Source> → <Target>

**Trigger:** <when this pattern activates>
**Direction:** sync | async
**Protocol:** REST / MQ / SFTP / …
**Diagram:** (Mermaid sequence or flow)
**Payload:** <schema reference>
**Error handling:** <dead letter / retry policy>
**NFR:** <latency target, throughput, ordering guarantee>
```

## Step 4: Validate

- [ ] Pattern matches the sync/async characterisation from Step 1
- [ ] Diagram is present and correctly directed
- [ ] Error path is documented
- [ ] Non-functional constraints are stated
- [ ] Entry added to the `integration-pattern-catalog` artefact
