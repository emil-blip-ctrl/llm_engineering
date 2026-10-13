---
name: archimate-generation
version: 1.0.0
type: technological
category: modelling
platform: ArchiMate 3.1 · Archi tool · Lucidchart
standards:
  - ArchiMate 3.1 (The Open Group)
  - Archi tool XML schema
description: >
  End-to-end skill: reads source diagrams (Lucidchart) or a YAML manifest,
  generates or updates target-architecture.yaml, and runs the Python generator
  to produce a .archimate file for the Archi modelling tool.
allowed-tools: Read, Write, Edit, Bash, Glob, WebSearch, mcp__claude_ai_Lucid__*
---

# ArchiMate Generation Skill

## Purpose

Produce a valid `.archimate` file from a structured YAML manifest describing a
target architecture. Can be invoked standalone or as a sub-step called by the
Azure Specialist Architect agent after discovery.

## Inputs

One of:

- **Lucidchart document URL** — agent reads diagrams via Lucid MCP then builds YAML
- **Existing `target-architecture.yaml`** — agent runs generator directly

Plus:

- **Feature project path** — directory containing `generate_dp_elements.py` (e.g. `C:\Github\DataPlatform`)
- **Output file name** — e.g. `DataPlatform.archimate`

## Steps

1. **Discover** (if no YAML provided)
   - Use Lucid MCP to read all relevant diagram pages
   - Extract elements per ArchiMate layer (Technology, Application, Motivation)
   - Identify parent/child containment and inter-element relationships

2. **Manifest** — write or update `target-architecture.yaml` in the feature project
   using the canonical schema (see ArchiMate Architect agent definition)

3. **Generate** — run the Python generator:
   ```
   C:\Github\CMDBtoArchimate\.venv\Scripts\python.exe generate_dp_elements.py
   ```
   Capture stdout/stderr; surface errors to the calling agent.

4. **Verify** — confirm the `.archimate` file was created or updated,
   report element count, relationship count, and view count from generator output.

## Output

Path to the generated `.archimate` file, ready to open in the Archi tool.

## Calling pattern (two-agent chain)

```
Azure Specialist Architect
  reads: Lucid diagrams / Azure CLI / CMDB
  produces: target-architecture.yaml

  ──calls──▶ archimate-generation skill

ArchiMate Architect (via archimate-generation)
  produces: FeatureProject.archimate
```

The Azure Specialist focuses on discovery and correctness of the architecture model;
the ArchiMate Architect focuses on serialisation and diagram layout only.

## Dependencies

- Lucid MCP (discovery step only)
- `C:\Github\CMDBtoArchimate\.venv` (Python 3.13 + ArchiXMLWriter)
- `generate_dp_elements.py` in the feature project (must exist before running step 3)
