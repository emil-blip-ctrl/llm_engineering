---
name: postman-collection-generator
version: 1.0.1
type: technological
category: testing-tools
platform: Postman · Newman · IBM APIC · ACE
standards:
  - Postman Collection v2.1 schema
  - OpenAPI 3.1 (OAI)
  - IBM APIC non-regression standards
description: >
  Generates a ready-to-import Postman collection (v2.1 JSON) for non-regression API testing in
  IBM integration environments (APIC, ACE, MQ). Use when the user wants to create, generate, or
  build a Postman collection — or supplies an OpenAPI/Swagger spec, payload examples, Kibana
  traces, or API code to test, migrate, or validate.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch, WebFetch
---

# /postman-collection-generator

Generates a production-ready Postman collection (v2.1 format) for non-regression API testing,
tailored for IBM integration stacks (APIC, ACE, MQ).

---

## Inputs to collect

Before generating, identify which inputs the user has available. Ask for what's missing if needed:

| Input | Required | Description |
|-------|----------|-------------|
| OpenAPI/Swagger YAML | **Required** | Defines endpoints, methods, schemas, parameters |
| Kibana trace payloads | Recommended | Real production request/response examples (JSON) |
| ACE flow / MQ code | Optional | Helps infer message structure, routing, error codes |
| API context | Optional | Environment name, API name, version, base path |

**The OpenAPI/Swagger YAML is mandatory.** If not provided, stop and ask for it before doing anything else. Do not attempt to generate a collection without it — the YAML is the authoritative source for endpoints, methods, request/response schemas, and path structures. All other inputs enrich the collection but cannot replace the YAML.

> **IDIT context**: If the API belongs to the IDIT ecosystem (Sapiens IDIT, TCS/Touring Club Suisse),
> always follow the IDIT documentation reading procedure below before generating any collection.

### IDIT documentation — reading procedure

The IDIT documentation is bundled as compressed text extracts in `references/idit-docs/`.
See `references/idit-docs/MANIFEST.md` for what each file contains.

**Step 1 — Decompress at runtime into /tmp**
```bash
gunzip -c references/idit-docs/doc-core.txt.gz > /tmp/idit-doc-core.txt
gunzip -c references/idit-docs/stories-recent.txt.gz > /tmp/idit-stories.txt
# Only decompress products.txt.gz if the API is product-specific
gunzip -c references/idit-docs/idit-docs/products.txt.gz > /tmp/idit-products.txt
```

**Step 2 — Search for the API or resource being tested**
```bash
grep -n -i "<api-name>\|<resource>\|<keyword>" /tmp/idit-doc-core.txt | head -40
```
This gives line numbers. Then read the surrounding context:
```bash
sed -n '<line_start>,<line_end>p' /tmp/idit-doc-core.txt
```

**Step 3 — Search stories for field-level detail**
```bash
grep -n -i "<api-name>\|<feature>" /tmp/idit-stories.txt | head -40
sed -n '<line_start>,<line_end>p' /tmp/idit-stories.txt
```

**What to extract and use for the collection:**
- Exact field names, data types, mandatory/optional → request body construction and response assertions
- Business rules per product → edge case test generation
- Error codes and fault messages → KO test cases
- Consumer-specific behaviour → folder structure and correct `client_id-x-{consumer}` variable

**Fallback**: if the PDFs themselves are also uploaded in the session (at `/mnt/user-data/uploads/`),
prefer reading them directly for sections not covered by the compressed extracts, using:
```bash
pdftotext -f <start> -l <end> /mnt/user-data/uploads/NIS-190526-063841.pdf -
```
Key page landmarks: Interfaces=541, Core entities=556, Claims=152, Contact=49, Billing=414, Products=789.

---

## Prerequisite & data dependency handling

Many APIs require data to pre-exist in the target system. This is especially common in insurance
domain systems (IDIT) where entities form strict dependency chains (contact → policy → claim).

### Step 1: Identify prerequisites for each endpoint

Before generating requests, analyse the endpoint and inputs to determine:
- What entities must exist (e.g. contact, policy, claim, invoice)
- What state they must be in (e.g. active policy, issued policy, not cancelled)
- Whether the prerequisite can be verified via another API in the collection

Use `references/idit-domain.md` for IDIT-specific chains. For other systems, infer from the API spec,
ACE flow logic, and Kibana traces (e.g. if a trace shows a `policyNumber` in the request, a policy must exist).

### Step 2: Choose the right documentation approach

Apply the following decision logic per endpoint:

#### Case A — Prerequisite is verifiable via an API in the collection
→ Generate a **Setup request** immediately before the test request, inside the same folder.
- Name it: `[SETUP] Verify <entity> exists`
- It should call the relevant GET endpoint (e.g. `GET /contacts/{{contactId}}`)
- Add a pre-request or test script that **fails fast with a clear message** if the data is missing:

```javascript
// In the Setup request Tests tab:
pm.test("PREREQUISITE: Contact exists in system", function () {
    pm.expect(pm.response.code).to.eql(200,
        "❌ SETUP FAILED: Contact {{contactId}} does not exist. " +
        "Create the contact before running this test.");
});
// Store a flag so the dependent test can check it
pm.environment.set("setup_contact_ok", pm.response.code === 200);
```

- In the dependent request's pre-request script:
```javascript
if (!pm.environment.get("setup_contact_ok")) {
    throw new Error("❌ Skipping: prerequisite contact not found. Run [SETUP] request first.");
}
```

#### Case B — Prerequisite cannot be verified via API (DB seed, reference data, manual setup)
→ Add a **`_Prerequisites` README item** at the top of the folder (a request with no HTTP method):
- Name it: `📋 Prerequisites for <Folder Name>`
- In its description, list all data that must exist with specific example values from Kibana traces
- Format as a checklist so testers can tick off before running

Example description:
```
## Prerequisites for Claims Tests

Before running any request in this folder, ensure the following data exists
in the target environment:

☐ Contact exists: contactId = CUST-001 (type: B2C, status: active)
☐ Active policy exists: policyNumber = POL-2024-00123 (product: ETI Travel, status: ISSUED)
☐ Loss event exists: lossEventId = EVT-789 (linked to POL-2024-00123, damage type: THEFT)

Source: Kibana trace 2024-03-15T10:23:44Z (correlation-id: abc-123-xyz)

If data is missing, contact the test data team or use the seed scripts in /test-data/.
```

#### Case C — Complex prerequisite chain (multiple dependent entities)
→ Create a dedicated **`🔧 Setup & Prerequisites`** folder at the TOP of the collection:
- Place setup requests in dependency order (contact → policy → claim)
- Each setup request checks its entity and sets an environment variable flag
- Add a clear README item explaining the full chain
- Main test folders then reference these flags

### Step 3: Folder naming convention with prerequisite visibility

```
Collection
├── 📋 _README - How to run this collection   ← top-level prereq overview
├── 🔧 Setup & Prerequisites                  ← only if complex chains exist
│   ├── [SETUP] Verify Contact exists
│   ├── [SETUP] Verify Policy exists
│   └── [SETUP] Verify Loss Event exists
├── 📁 Contacts
│   ├── 📋 Prerequisites for Contacts
│   ├── GET /contacts/{contactId} - Happy Path
│   └── GET /contacts/{contactId} - Error: Not Found (404)
├── 📁 Policies
│   ├── [SETUP] Verify Contact exists
│   ├── GET /policies/{policyNumber} - Happy Path
│   └── ...
└── 📁 Claims
    ├── [SETUP] Verify Contact exists
    ├── [SETUP] Verify Policy exists
    ├── [SETUP] Verify Loss Event exists
    ├── POST /loss-events - Happy Path (FNOL)
    └── GET /loss-events/{lossEventId} - Happy Path
```

---

## Output

A single Postman Collection v2.1 `.json` file, delivered as a downloadable file.

### Structure of the generated collection

```
Collection: <API Name> - Non-Regression Tests
├── 📁 <Tag or Resource> (one folder per endpoint group)
│   ├── <METHOD> <path> - Happy Path
│   ├── <METHOD> <path> - Error Case: <code>
│   └── <METHOD> <path> - Edge Case: <description>
└── 📁 _Environment Template (optional)
    └── README: variables to fill in
```

---

## Generation rules

### 1. Collection metadata
- `info.name`: `<API Name> - Non-Regression Tests`
- `info.schema`: always `https://schema.getpostman.com/json/collection/v2.1.0/collection.json`
- Add a top-level `description` summarizing the API and migration context if known

### 2. Variables (do NOT hardcode credentials or URLs)
Always use Postman variables for:
- `{{baseUrl}}` — base URL of the API
- `{{apiKey}}` — API key if applicable
- `{{bearerToken}}` — auth token if applicable
- Any other environment-specific values found in the spec or traces

Add a comment in the collection description reminding the user to configure these in a Postman Environment.

### 3. Folders
- Create one folder per OpenAPI `tag` or resource path prefix (e.g., `/orders`, `/payments`)
- If no tags exist, group by first path segment
- For MQ/async APIs: create a folder per queue/topic or message type

### 4. Requests
For each endpoint in the spec (or each unique operation found in traces):

**Request setup:**
- Set correct HTTP method and URL using `{{baseUrl}}/path`
- Add all required headers (Content-Type, Accept, X-IBM-Client-Id, correlation IDs, etc.)
- Use path parameters as Postman variables: `/orders/{{orderId}}`
- Add query parameters with example values from the spec or traces
- Body: use real Kibana trace payload if available, otherwise generate a minimal valid example from the schema

**Generate multiple test cases per endpoint when data allows:**
- `Happy Path` — valid request, expect 2xx
- `Error cases` — e.g., 400, 404, 422, 500 if described in spec or seen in traces
- `Edge cases` — empty body, missing optional fields, boundary values if inferable

### 5. Test scripts (Postman `Tests` tab — JavaScript)

Add to every request:

```javascript
// Status code check
pm.test("Status code is expected", function () {
    pm.expect(pm.response.code).to.be.oneOf([200, 201, 202]); // adjust per case
});

// Response time
pm.test("Response time is acceptable", function () {
    pm.expect(pm.response.responseTime).to.be.below(5000);
});
```

Add when response schema is known:

```javascript
// Schema validation
const schema = { /* inline JSON Schema from OpenAPI */ };
pm.test("Response matches schema", function () {
    const jsonData = pm.response.json();
    pm.expect(tv4.validate(jsonData, schema)).to.be.true;
});
```

Add when Kibana trace provides expected response values:

```javascript
// Field value assertions
pm.test("Response contains expected fields", function () {
    const jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property("orderId");
    pm.expect(jsonData.status).to.eql("CONFIRMED");
});
```

Add for backwards compatibility / migration non-regression:

```javascript
// Backwards compatibility check
pm.test("Response structure is backwards compatible", function () {
    const jsonData = pm.response.json();
    // Assert all fields present in the original (pre-migration) response are still here
    ["field1", "field2", "field3"].forEach(function(field) {
        pm.expect(jsonData).to.have.property(field);
    });
});
```

### 6. IBM APIC gateway — mandatory rule

**ALL requests in the collection MUST target the APIC-exposed URL. Never call internal ACE URLs directly.**

This is a hard constraint: the goal of these collections is non-regression testing of the full
integration stack as seen from outside — through the APIC gateway — not unit-testing internal ACE flows.

#### Why this matters
- APIC enforces security policies (client ID/secret validation, OAuth, rate limiting, TLS)
- APIC may apply request/response transformations on top of ACE
- A test that bypasses APIC does not validate what external consumers actually experience
- The migration non-regression test must prove the new stack behaves identically at the APIC boundary

#### Multi-environment strategy — QA / ACP / PROD

There are three environment chains, run in order: **QA → ACP (Acceptance/Pre-Production) → PROD**.

The collection itself must be **fully environment-agnostic** — no URLs, credentials, or environment-specific values hardcoded anywhere. All environment-specific values live in **Postman Environment files**, one per environment. Generate all three alongside the collection.

##### TCS URL and variable naming conventions

The real TCS environment files use the following exact variable names. **Always use these — do not invent alternatives.**

| Variable key | QA value pattern | ACP value pattern | Description |
|---|---|---|---|
| `url-apic` | `https://iapi-qa.tcsgroup.ch/tcs/qa` | `https://iapi-acp.tcsgroup.ch/tcs/acp` | Internal APIC URL (intranet) |
| `url-apic-external` | `https://eapi-qa.tcsgroup.ch/tcs/qa` | `https://eapi-acp.tcsgroup.ch/tcs/acp` | External APIC URL (internet) |
| `url-ace` | `https://tcsis-qa.tcsgroup.ch:7083` | `https://tcsis-acp.tcsgroup.ch:7083` | ACE direct URL — **for reference only, never use in requests** |
| `url-oauth2-access-token` | `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token` | same | Azure AD token endpoint |
| `client_id-x-{consumer}` | `{{vault:client_id-q-{consumer}}}` | `{{vault:client_id-a-{consumer}}}` | IBM Client ID per consumer app |
| `client_secret-x-{consumer}` | `{{vault:client_secret-q-{consumer}}}` | `{{vault:client_secret-a-{consumer}}}` | IBM Client Secret per consumer app |

Key observations:
- **Credentials use Vault references** (`{{vault:...}}`), not hardcoded values — preserve this pattern
- **Consumer suffix pattern**: `client_id-x-{consumer}` where `{consumer}` is the calling system (e.g. `tcsch-batch`, `lexforyou-default`, `assys-backend`, `ace-esb`)
- **Environment letter in vault key**: `q` = QA, `a` = ACP, `p` = PROD
- The `url-ace` variable exists in the env file but **must never be used as a request target**

##### Internal vs external network — two URL variables, one collection

APIs accessible from both internal network (intranet) and external network (internet) are handled within **a single collection** using **separate folders**, one per consumer/network context:

- Requests targeting internal consumers (e.g. batch jobs, ACE-ESB, backend services) → use `{{url-apic}}`
- Requests targeting external consumers (e.g. partner APIs, internet-facing apps like LexForYou) → use `{{url-apic-external}}`

**Naming convention for collections:**
- Internal: `<domain>-api-<resource>` (e.g. `insurance-claims-api-claims`)
- External: `<domain>-api-<resource>-internet` (e.g. `insurance-claims-api-claims-internet`)

When both exist, generate **two separate collection files** following this pattern — the split between internal and external is a collection-level separation, not just a folder within one collection.

##### Authentication patterns

Two patterns are used depending on the consumer type:

**Pattern 1 — Internal / intranet (IBM Client-Id/Secret headers)**
Used by backend systems (batch, ACE-ESB, internal apps). No OAuth token:
```json
"header": [
  { "key": "X-IBM-Client-Id", "value": "{{client_id-x-{consumer}}}", "type": "text" },
  { "key": "X-IBM-Client-Secret", "value": "{{client_secret-x-{consumer}}}", "type": "text" }
]
```
No `auth` block on the request — authentication is purely via headers.

**Pattern 2 — External / internet (OAuth2 client credentials + x-tcs-client-id header)**
Used by external partners and internet-facing consumers (e.g. LexForYou, Baloise):
```json
"auth": {
  "type": "oauth2",
  "oauth2": [
    { "key": "scope", "value": "{{client_id-x-{consumer}}}/.default", "type": "string" },
    { "key": "clientSecret", "value": "{{client_secret-x-{consumer}}}", "type": "string" },
    { "key": "clientId", "value": "{{client_id-x-{consumer}}}", "type": "string" },
    { "key": "accessTokenUrl", "value": "{{url-oauth2-access-token}}", "type": "string" },
    { "key": "grant_type", "value": "client_credentials", "type": "string" },
    { "key": "addTokenTo", "value": "header", "type": "string" },
    { "key": "client_authentication", "value": "body", "type": "string" }
  ]
},
"header": [
  { "key": "x-tcs-client-id", "value": "{{client_id-x-{consumer}}}", "type": "text" }
]
```
Note: external requests use `x-tcs-client-id` (lowercase, TCS-specific), **not** `X-IBM-Client-Id`.

##### Folder structure convention

Requests are grouped by **consumer** (the calling system), not by HTTP method or resource. Each consumer gets its own top-level folder named after the system (e.g. `TCS.CH Batch`, `LEXFORYOU`, `ASSYS`):

```
Collection: insurance-claims-api-claims
└── 📁 TCS.CH Batch
    ├── Post Insurance Claim
    ├── Get Claim
    └── Post Find Claims

Collection: insurance-claims-api-claims-internet
└── 📁 LEXFORYOU
    └── Post Insurance Claim
```

##### Request naming convention

Use plain descriptive names without HTTP method prefix: `Post Insurance Claim`, `Get Claim`, `Post Find Claims`.
For test cases with expected outcome: prefix with `OK - ` or `KO - ` (e.g. `OK - Send a set of demands`, `KO - Send a set of demands`).

##### URL path structure

URL path follows: `{{url-apic}}/<domain>/<version>/<resource-path>`
Example: `{{url-apic}}/insurance-claims/v2/claims/claim`

The API domain segment (e.g. `insurance-claims`, `clients-prospects`, `services`) is derived from the `x-ibm-name` field in the YAML or the collection/API name.

##### Test data variables

Environment-specific test data IDs (claim IDs, policy numbers, contact IDs) are stored as **collection-level variables**, not environment variables, with the environment name as a prefix:
```json
"variable": [
  { "key": "QA-Claim-ID", "value": "23103-0000306", "type": "string" }
]
```
This keeps test data visible in the collection and separate from infrastructure config in the env files.

##### Environment file format — exact TCS structure

```json
{
  "name": "env-tcs-global-qa",
  "values": [
    { "key": "url-apic", "value": "https://iapi-qa.tcsgroup.ch/tcs/qa", "type": "default", "enabled": true },
    { "key": "url-apic-external", "value": "https://eapi-qa.tcsgroup.ch/tcs/qa", "type": "default", "enabled": true },
    { "key": "url-ace", "value": "https://tcsis-qa.tcsgroup.ch:7083", "type": "default", "enabled": true },
    { "key": "url-oauth2-access-token", "value": "https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token", "type": "default", "enabled": true },
    { "key": "client_id-x-{consumer}", "value": "{{vault:client_id-q-{consumer}}}", "type": "default", "enabled": true },
    { "key": "client_secret-x-{consumer}", "value": "{{vault:client_secret-q-{consumer}}}", "type": "default", "enabled": true }
  ],
  "_postman_variable_scope": "environment"
}
```

Generate one file per environment (`env-tcs-global-qa`, `env-tcs-global-acp`, `env-tcs-global-prod`), replacing the vault key suffix `q` → `a` → `p` and the hostnames accordingly.

#### When ACE flow / MQ code is provided as input

Use ACE/MQ artefacts **only to inform test content**, never as the target URL:
- Extract message field names, mandatory vs optional fields, data types → use for request body construction
- Identify error codes and fault messages thrown by the flow → generate corresponding error test cases
- Note any ACE transformation logic (e.g. field renaming, XML↔JSON conversion, enrichment) → use to write more precise response assertions that reflect what APIC returns post-transformation
- If a flow calls MQ internally, that is invisible to the Postman test — test only the synchronous HTTP response at the APIC layer

#### MQ-backed / async APIs

If an API triggers an async MQ process internally:
- Still call the APIC HTTP endpoint as normal — test the synchronous acknowledgement response (typically 202 Accepted)
- Add a test asserting the 202 and any correlation/tracking ID in the response
- Add a description note: "This request triggers an async MQ process. Functional completion must be verified separately (e.g. via a downstream GET, a status poll, or manual verification in the back-office)."
- If a polling endpoint exists, add it as a follow-up request in the same folder

### 7. Kibana trace inputs
When Kibana traces are provided:
- Use the request body verbatim as the example body (sanitize sensitive data if instructed)
- Use the response body to generate field-level assertions
- Infer headers from the trace (Content-Type, correlation IDs, etc.)
- If multiple traces exist for the same endpoint, create one test item per trace variant

---

## Output instructions

Generate and present the following files:

1. **Internal collection**: `<domain>-api-<resource>.postman_collection.json` (uses `{{url-apic}}`)
2. **External collection**: `<domain>-api-<resource>-internet.postman_collection.json` (uses `{{url-apic-external}}`) — only if the API has external/internet-facing consumers
3. **QA environment**: `env-tcs-global-qa.postman_environment.json`
4. **ACP environment**: `env-tcs-global-acp.postman_environment.json`
5. **PROD environment**: `env-tcs-global-prod.postman_environment.json`
6. **Newman run script**: `run-tests.sh`
7. **Jenkinsfile**: `Jenkinsfile`

Write all files to `/mnt/user-data/outputs/`, then present them all with `present_files`.

Briefly summarise what was generated: number of folders, requests, test scripts, and a reminder on how to import and use the environment files.

See `references/postman-v21-schema.md` for the exact JSON structure for both the collection and environment files.

---

## Newman / CLI / Jenkins compatibility

The collection must be executable in three modes without any modification:

### Mode 1 — Postman UI
Standard import of collection + environment file. No constraints beyond valid v2.1 JSON.

### Mode 2 — Newman CLI

Newman is the official Postman CLI runner. Generate a `run-tests.sh` script:

```bash
#!/bin/bash
# Usage: ./run-tests.sh [qa|acp|prod]
# Requires: npm install -g newman newman-reporter-htmlextra

ENV=${1:-qa}
COLLECTION="<api-name>-postman-collection.json"
ENVIRONMENT="env-tcs-global-${ENV}.postman_environment.json"
REPORT_DIR="./reports"

mkdir -p "$REPORT_DIR"

echo "Running collection against environment: $ENV"

newman run "$COLLECTION" \
  --environment "$ENVIRONMENT" \
  --reporters cli,htmlextra,junit \
  --reporter-htmlextra-export "$REPORT_DIR/<api-name>-${ENV}-report.html" \
  --reporter-junit-export "$REPORT_DIR/<api-name>-${ENV}-results.xml" \
  --color on \
  --bail

EXIT_CODE=$?
echo "Newman exited with code $EXIT_CODE"
exit $EXIT_CODE
```

Notes:
- `--bail` stops on first test failure — remove if you want all tests to run regardless
- JUnit XML output is what Jenkins reads for test results
- `htmlextra` produces a rich HTML report; install with `npm install -g newman-reporter-htmlextra`
- Vault-referenced credentials (`{{vault:...}}`) in the env file are resolved by the Postman Vault integration when running in Postman UI. For Newman CLI, inject them via `--env-var` flags (see Jenkinsfile below)

### Mode 3 — Jenkins pipeline

```groovy
pipeline {
    agent any

    parameters {
        choice(
            name: 'TARGET_ENV',
            choices: ['qa', 'acp', 'prod'],
            description: 'Target environment (qa → acp → prod)'
        )
        string(
            name: 'CONSUMER',
            defaultValue: 'tcsch-batch',
            description: 'Consumer app name (e.g. tcsch-batch, lexforyou-default, ace-esb)'
        )
    }

    environment {
        COLLECTION  = '<api-name>-postman-collection.json'
        ENV_FILE    = "env-tcs-global-${params.TARGET_ENV}.postman_environment.json"
        REPORT_DIR  = 'reports'
        // Vault key suffix per env: qa=q, acp=a, prod=p
        VAULT_SUFFIX = params.TARGET_ENV == 'qa' ? 'q' : (params.TARGET_ENV == 'acp' ? 'a' : 'p')
    }

    stages {
        stage('Install Newman') {
            steps {
                sh 'npm install -g newman newman-reporter-htmlextra || true'
            }
        }

        stage('Run Postman Collection') {
            steps {
                withCredentials([
                    string(credentialsId: "client_id-${VAULT_SUFFIX}-${params.CONSUMER}", variable: 'CLIENT_ID'),
                    string(credentialsId: "client_secret-${VAULT_SUFFIX}-${params.CONSUMER}", variable: 'CLIENT_SECRET')
                ]) {
                    sh """
                        mkdir -p ${REPORT_DIR}
                        newman run ${COLLECTION} \\
                          --environment ${ENV_FILE} \\
                          --env-var "client_id-x-${params.CONSUMER}=${CLIENT_ID}" \\
                          --env-var "client_secret-x-${params.CONSUMER}=${CLIENT_SECRET}" \\
                          --reporters cli,htmlextra,junit \\
                          --reporter-htmlextra-export ${REPORT_DIR}/<api-name>-${params.TARGET_ENV}-report.html \\
                          --reporter-junit-export ${REPORT_DIR}/<api-name>-${params.TARGET_ENV}-results.xml \\
                          --color off \\
                          --bail
                    """
                }
            }
        }
    }

    post {
        always {
            junit "${REPORT_DIR}/<api-name>-${params.TARGET_ENV}-results.xml"
            publishHTML(target: [
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: "${REPORT_DIR}",
                reportFiles: "<api-name>-${params.TARGET_ENV}-report.html",
                reportName: 'Newman Test Report'
            ])
        }
        success { echo "✅ All tests passed on ${params.TARGET_ENV}" }
        failure { echo "❌ Tests failed on ${params.TARGET_ENV} — check the report" }
    }
}
```

Key points:
- **Vault references** in the env file (`{{vault:client_id-q-{consumer}}}`) are overridden at runtime via `--env-var` with the real secret fetched from Jenkins credentials — matching the `client_id-{vault_suffix}-{consumer}` naming convention
- The `VAULT_SUFFIX` maps `qa→q`, `acp→a`, `prod→p` to match the TCS vault key convention
- `--color off` prevents ANSI codes from polluting Jenkins console logs
- `--bail` fails the pipeline fast — right behaviour for a promotion gate

### Newman compatibility rules — apply to all generated requests

To ensure the collection runs correctly in Newman (not just Postman UI):

- **No Postman UI-only features**: do not use visualizer scripts (`pm.visualizer.set()`), do not rely on manual environment variable editing mid-run
- **No interactive prompts**: all variables must be resolvable from the environment file or `--env-var` flags
- **Pre-request scripts must be self-contained**: do not rely on state set by a previous request unless using `pm.environment.set()` / `pm.environment.get()` — these work in Newman
- **Test scripts use only Newman-supported libraries**: `pm.*`, `tv4`, `CryptoJS`, `xml2Json`, `cheerio` are available; do not use browser APIs
- **File uploads**: Newman supports `formdata` bodies with `--working-dir` flag; if the API requires file upload, note this in the request description and add the `--working-dir` flag to the run script
- **Iteration data**: if the same endpoint needs to be tested with multiple data sets, note in the README that Newman supports `--iteration-data <csv-or-json>` for data-driven runs

---

## Edge cases and guidance

- **No schema available**: generate placeholder body with `TODO` comments inside strings
- **Async MQ APIs**: generate HTTP wrapper requests if an HTTP adapter exists; otherwise document the message format as a collection description with no runnable requests, and suggest using a Postman MQ plugin or custom pre-request script
- **Multiple environments**: remind user to create separate Postman Environments for dev/test/prod rather than duplicating the collection
- **Large APIs (>30 endpoints)**: still generate all of them; organize folders carefully and add a top-level README request with no method that documents the collection structure

---

## References

- `references/postman-v21-schema.md` — Postman Collection v2.1 JSON structure. Read before generating JSON output.
- `references/idit-domain.md` — Synthesised IDIT domain model: entities, relationships, API catalogue, prerequisite chains, migration notes.
- `references/idit-docs/MANIFEST.md` — Index of bundled compressed IDIT documentation extracts. Read this to know which file to decompress for a given API.
- `references/idit-docs/doc-core.txt.gz` — Core API reference + domain setup (interfaces, claims, billing, sales, contacts). ~366KB text, 87KB compressed.
- `references/idit-docs/products.txt.gz` — All TCS product definitions (Membership, ETI Travel, Legal Protection, etc.). ~468KB text, 39KB compressed.
- `references/idit-docs/stories-recent.txt.gz` — Most recent 200 pages of user stories with API field-level detail. ~315KB text, 82KB compressed.
