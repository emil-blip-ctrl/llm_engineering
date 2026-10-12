---
name: mdp-generator
description: DataPlatform repo has a second generator (generate_mdp_views.py) for the MDP prod model, separate from generate_dp_elements.py
metadata:
  type: project
---

`C:\Github\DataPlatform` has TWO generators that both write `DataPlatform.archimate`:

- `generate_dp_elements.py` — reads `target-architecture-sc3.yaml` (default), assisted-layout engine (orgchart/nested/grid). The Sc3 model.
- `generate_mdp_views.py` — reads `target-architecture-mdp.yaml`, hand-laid-out. Produces 3 views: "MDP · Platform Overview (prod)", "MDP · Data Domain Map (prod)", and "MDP · Data Hub — Zone Detail (prod)". ~140 elements, ~109 rels, 3 views. View 3 = `build_zone_detail_view` inline in main(): 4 vertical zone Groupings (ing/trn/dq/srv) each nesting workspace + NCC(3 managed-PE-rule TechnologyServices), shared-infra band (metastore + storage) beneath, 6 hub domain DataObjects (seed `do-<domain>`) in the Transformation box. Uses AssignmentRelationship (ws→zone TechnologyService) — handler added to the `_m` dispatch map.

**Why:** The MDP overview/domain views need elements absent from the read-only MDP YAML (Hub VNet, Azure Firewall, DNS Resolver, 5 Private DNS Zones, PE subnet + 13 private endpoints, Databricks Cloud serverless pool, 10 NCCs each nesting 3 managed-PE sub-nodes, data products as nested ApplicationFunctions). Those are supplied in the script from the design spec; the YAML only provides workspaces, NCCs, UC catalogs, domains, products.

**How to apply:** Running `generate_mdp_views.py` OVERWRITES `DataPlatform.archimate` with the MDP model (not Sc3). Run command: `C:\Github\CMDBtoArchimate\.venv\Scripts\python.exe generate_mdp_views.py`. The two scripts clobber each other's output — only one model lives in the file at a time.

**Gotcha:** `target-architecture-mdp.yaml` (read-only) has unquoted `description:` scalars containing an inner ": " (e.g. fab-corpcom/fab-insurance "… Domain: CorpCom…") that break `yaml.safe_load`. `generate_mdp_views.py` quotes those lines in-memory before parsing rather than editing the source. See [[project-dataplatform]].
