---
name: project-lineage-encoding
description: Field-level data-lineage encoding for ChromaDB metadata in CMDBtoArchimate (Phase 1)
metadata:
  type: project
---

Per-attribute data lineage in CMDBtoArchimate is encoded as PREFIXED FLAT KEYS: `lin.<attr>.<field>` where field ∈ {system, ref, sheet, column, row, note}. Helper: `cmdb_to_archimate/lineage.py` (`add_attribute_lineage`, `build_attribute_lineage`, `lineage_key`).

**Why:** ChromaDB metadata is flat (str/int/float/bool, no nested dicts). The ArchiMate generator emits one `<property key=value>` per metadata key and drops falsy values (generate_complete_archimate.py:145-149), so flat keys render as clean individual properties; a single JSON blob would be one opaque property. Chosen over JSON-string scheme for readability + no escaping bugs.

**How to apply:** ALL future ChromaDB writers (apic/moexsrv/mqsc/pubsub extractors) must use this helper, not hand-write `lin.*` keys. source_system vocab: excel/apic/moexsrv/mqsc/pubsub. Universal fields system+ref; Excel-only sheet/column/row. Phase 1 wired only the Excel importer; typed collections (API/ACE/Moex) inherit ISS lineage via `_forward_iss_lineage` because they build from ISS ChromaDB metadata, not raw rows.

**Phase 3 (MQSC + pub/sub):** MQSC queue/topic/sub lineage emitted in their `to_vector_document` via private `_add_mqsc_lineage(metadata)` (models.py, classes MQQueueDefinition/MQTopicDefinition/MQSubscription); system=`mqsc`, ref=`source_file`. Pub/sub: `MessagingEndpoint`/`MessagingRelationship`/`ACEToACERelationship` got an optional `lineage: Dict` field (default empty) merged via `metadata.update(self.lineage)` — because these dataclasses are SHARED by non-pubsub callers (ESQL/flow analysis), lineage must be injected by the caller (resolve_pubsub_topology.py via local `build_lineage`), NOT hardcoded in to_vector_document. system=`pubsub`, ref=resolved topic string (or artifact name for synthesized ACE docs), every attr gets a `note` (values are computed/derived).

**Phase 2 (APIC/MOEX API records):** Lineage for `API` is emitted in `API.to_vector_document` (models.py) via a private `_add_apic_moex_lineage(metadata)` — NOT at the two `API(...)` construction sites in extractors.py (lines 149 APIC, 505 MOEX). Reason: serialization is the single point where all attrs become flat metadata, and it runs AFTER the `source="both"` merge (extractors.py:675). Rule: only emit when `source in {apic,moexsrv,both}`; `both`→`apic` (APIC authoritative) + note. source_ref = `self.source_folder`. Excel-sourced APIs skipped so ISS lineage isn't clobbered. CMDBId rejects MOEX-* placeholder ids in direct construction — real path uses api_cmdb_lookup→CMP id.
