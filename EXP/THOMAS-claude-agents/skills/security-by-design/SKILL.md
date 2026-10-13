---
name: security-by-design
version: 1.0.0
type: methodological
category: security
standards:
  - OWASP Threat Modeling (STRIDE)
  - OWASP Top 10 (2021)
  - ISO/IEC 27001:2022 — Information Security
  - TCS security baseline (Key Vault, TLS, corporate CA)
description: >
  Apply security-by-design principles during architecture and development: threat
  modelling, secure defaults, least privilege, defence in depth. Use when designing
  a new component, reviewing an existing design for security gaps, or producing a
  security section for an ADR or HLD.
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, TodoWrite
---

# /security-by-design — Security by Design

## Step 1: Define the Trust Boundary

Draw or describe the trust boundary:
- What assets are inside (data, credentials, services)?
- What actors are outside (users, external APIs, other systems)?
- What are the entry/exit points (APIs, queues, file shares)?

## Step 2: Threat Model (STRIDE)

For each entry/exit point, consider:

| Threat | STRIDE | Mitigation |
|---|---|---|
| Spoofing identity | S | AuthN: OAuth 2.0 / mTLS / API keys |
| Tampering with data | T | Integrity: HMAC, TLS in transit, encryption at rest |
| Repudiation | R | Audit log: immutable, timestamped |
| Information disclosure | I | AuthZ: RBAC / ABAC, data classification, masking |
| Denial of service | D | Rate limiting, circuit breakers, WAF |
| Elevation of privilege | E | Least privilege, no wildcard permissions |

## Step 3: Apply TCS Security Baseline

Mandatory controls (non-negotiable):
- **No Key Vault** — do not design credential retrieval via Azure Key Vault without explicit approval
- **TLS** — never disable certificate verification; use the TCS corporate CA bundle
- **Secrets** — never hardcode credentials; use environment variables or managed identity
- **Logging** — log authentication events and failures; never log secrets or PII

## Step 4: Document Security Decisions

For each significant security control or trade-off, write an ADR section or inline note:
- What threat it mitigates
- What alternative was considered
- Why this control was chosen

## Step 5: Checklist

- [ ] Trust boundary defined
- [ ] STRIDE applied to all entry/exit points
- [ ] TCS baseline controls applied
- [ ] No secrets in code or config files
- [ ] TLS enforced on all external calls
- [ ] Audit logging covers authentication and sensitive operations
