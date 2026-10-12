# IDIT Domain Reference

IDIT is the **Sapiens IDIT** Policy and Claims Administration System used by TCS (Touring Club Suisse).
It is being migrated from an **on-premises version to a SaaS version**, with a major version upgrade
(4-5 core versions ahead). The migration involves rebuilding all integrations via IBM APIC/ACE/MQ.

This reference captures the key domain entities, their relationships, the main APIs exposed or consumed
by IDIT, and the prerequisite data dependencies relevant for non-regression testing.

---

## System context

IDIT sits at the center of an integration ecosystem that includes:
- **Salesforce** — CRM, contact management, customer 360, policy/proposal events
- **SAP** — Financial postings (GL, payments, claim payments, exchange rates, service providers)
- **SIX** — Credit card payment processing
- **La Poste / BVR** — Incoming payments (QR-BVR, BVR reference)
- **ECM** — Document management (document generation, notifications)
- **KOFAX** — Incoming document capture
- **ASSYS / ALIS** — External claims management systems (legal protection, etc.)
- **DPM** — Data/policy/claims replication
- **Azure Active Directory** — User authorization
- **BI** — Business intelligence replication
- **IPS V1/V2, Travel Safety, Protect-ID** — Case/Service Management systems
- **eCommerce / e-care** — Digital sales channel (HUI: Headless UI)
- **Various Sales GUIs** — Section, Patrolcraft, Partner, Sales Guided UIs

---

## Core domain entities and their relationships

### Contact (Client)
- A **Contact** is a person or legal entity (B2C physical person, B2B legal entity)
- Key attributes: entity type, title, email(s), phone(s), address, family relationships, sub-type (VIP, TCS employee), camping section, Baloise partnership flag, blacklist flag
- A contact may have: family relationships (spouse, child, etc.), multiple addresses, multiple email types
- Contacts are mastered in **Salesforce** and synced to IDIT
- **A contact must exist before any policy, proposal, or claim can be created for them**

### Policy / Proposal
- A **Proposal** is a quote/basket not yet issued
- A **Policy** is an issued insurance contract
- Key attributes: policy number, product, product version, product line, covers, insured persons (beneficiaries), billing group, attributes (family variant, motorized variant, etc.), payment slip (QR-IBAN), endorsement history, cancellation reason, insured object details
- A policy belongs to exactly one **Contact**
- A policy may have multiple **covers** and multiple **beneficiaries**
- A policy may have **endorsements** (mid-term changes) and a **cancellation**
- **A contact must exist before a policy can be created**
- Product families include: Membership (TCS), Travel (ETI), Legal Protection, Bike, Camping, Carte Entreprise (company card), Kids Bracelet

### Endorsement / Cancellation
- An **Endorsement** is a mid-term policy change (e.g. adding a beneficiary, changing cover)
- A **Cancellation** terminates a policy
- Both require an existing active policy
- Cancellation reasons and endorsement reasons are reference-data driven

### Claim / Loss Event
- A **Loss Event** (FNOL: First Notice of Loss) is the initial claim registration
- A **Claim** is derived from a loss event and attached to a specific policy
- Key attributes: loss event number, claim number, damage status, damage reason, reserves, recoveries, payments, task history, service providers involved, external system references (ASSYS/ALIS)
- **A claim requires an existing contact AND an existing active policy**
- Claims can exist in both IDIT and external systems (ASSYS/ALIS) for the same event

### Invoice / Payment Slip
- An **Invoice** is generated upon policy issuance or renewal
- A **Payment Slip** carries QR-IBAN / BVR reference for payment
- Payment methods: Cash, Credit Card (SIX), BVR, Twint, PostFinance Card, Bank Transfer
- Incoming payments matched to invoices via BVR reference or credit card capture

### Basket / Cart (HUI)
- A **Basket** is a digital shopping cart containing one or more proposals (used in eCommerce)
- Basket validation performs underwriting (UW) checks
- After validation, policies are issued via `issuePolicyList`

---

## Main APIs exposed by IDIT

### Policy / Proposal / Endorsement APIs
| API | Method | Description | Prerequisites |
|-----|--------|-------------|---------------|
| Get Policy | GET | Returns full policy details (covers, beneficiaries, billing, attributes) | Policy must exist; contact must exist |
| Get Proposal | GET | Returns proposal/quote details | Proposal must exist; contact must exist |
| Get Endorsement | GET | Returns endorsement details | Policy must exist with at least one endorsement |
| Put Proposal / Put ProposalList | PUT | Validate cart (underwriting checks) | Contact must exist; product must be configured |
| Issue Policy List | POST | Issues one or more policies from proposals | Proposals must exist in basket; contact must exist |
| Post Renewal Endorsement | POST | Adds post-renewal endorsements | Policy must exist and be renewed |
| Reject Proposal | POST | Rejects a proposal | Proposal must be in pending state |

### Contact APIs
| API | Method | Description | Prerequisites |
|-----|--------|-------------|---------------|
| Get Contact | GET | Returns contact details | Contact must exist in IDIT (synced from Salesforce) |
| Put/Post Contact | PUT/POST | Creates or updates a contact | None (but entity type, title must be valid reference data) |
| Get Contacts (search) | GET | Search contacts by attributes | None |

### Claims / Loss Event APIs
| API | Method | Description | Prerequisites |
|-----|--------|-------------|---------------|
| GET Loss Events / Claims | GET | Returns claim/loss event details (V2 core version) | Contact must exist; policy must exist; loss event must exist |
| Post Loss Event (FNOL) | POST | Creates a new loss/claim notification | Contact must exist; active policy must exist covering the loss type |

### HUI (Headless UI / eCommerce) APIs
| API | Method | Description | Prerequisites |
|-----|--------|-------------|---------------|
| Get Product Details | GET | Product catalog with buyable products and their attributes | None (reference data must be configured) |
| Get Reference Data | GET | Returns reference/lookup data | None |
| Get Buyable Products | GET | List of products available for sale | None |
| Get Portfolio | GET | Customer's existing policies | Contact must exist |
| Get Proposals List | GET | Customer's open proposals/basket | Contact must exist |
| Validate Cart | PUT | Validates basket with UW checks | Contact + proposals must exist in basket |
| Issue Policies List | POST | Issues policies from basket | Validated basket must exist; contact must exist; credit card capture or payment initialized |
| Generate Payment Slip | POST/GET | Generates QR-BVR payment slip | Policy must exist; invoice must exist |
| Get Payment Slip details | GET | Returns payment slip details with QR-IBAN | Policy must exist |

### Payment APIs
| API | Method | Description | Prerequisites |
|-----|--------|-------------|---------------|
| POST /online-payment (Initialize) | POST | Initializes CC payment, opens SIX iFrame | Proposals must exist in basket |
| PUT /online-payment (Capture) | PUT | Captures CC payment after policy issuance | Initialize must have been called; policies issued successfully |
| POST /online-payments-with-alias | POST | CC payment using stored alias | Contact must have a registered CC alias |
| Incoming Payment (BVR) | POST | Registers incoming BVR payment | Invoice must exist; BVR reference must match |

### SAP Integration APIs (outgoing from IDIT)
| API | Direction | Description | Prerequisites |
|-----|-----------|-------------|---------------|
| Outgoing Payment | IDIT→SAP | Sends payment data to SAP | Policy/invoice must exist |
| Outgoing Claim Payments | IDIT→SAP | Sends claim payment data | Claim must exist with approved payment |
| General Ledger | IDIT→SAP | GL transaction posting | Financial transaction must exist in IDIT |
| Exchange Rate | SAP→IDIT | Exchange rate feed | None |
| Service Providers | IDIT→SAP | Service provider payment | Claim + service provider statement must exist |

### Document APIs
| API | Method | Description | Prerequisites |
|-----|--------|-------------|---------------|
| Post Business Event | POST | Triggers document generation (CCM) | Policy/claim/contact event must have occurred |
| Document Management | GET/POST | Upload/retrieve documents | Policy or claim must exist |

### Salesforce Integration APIs
| API | Direction | Description |
|-----|-----------|-------------|
| Contact management (sync) | SF→IDIT | Contact create/update pushed from Salesforce |
| 360 view | IDIT→SF | Policy/proposal/claim summary for customer 360 |
| Policy/Proposal change notifications | IDIT→SF | Event-driven notifications on policy changes |
| Customer interactions | IDIT→SF | Interaction history |
| Deeplinks | IDIT→SF | Links from SF to IDIT policy/claim screens |

---

## Prerequisite dependency chains

This section maps what data must exist in the target system before each test can run.

### Chain 1: Contact only
```
Contact exists in IDIT (synced from Salesforce or created via API)
└── Get Contact ✓
└── Get Portfolio ✓ (may return empty list)
└── Get Proposals List ✓ (may return empty list)
```

### Chain 2: Contact + Policy
```
Contact exists
└── Active Policy exists for that contact
    └── Get Policy ✓
    └── Get Endorsement ✓ (if endorsements exist)
    └── Get Payment Slip ✓
    └── Get Portfolio ✓ (returns the policy)
```

### Chain 3: Contact + Policy + Claim
```
Contact exists
└── Active Policy exists
    └── Loss Event / Claim exists linked to that policy
        └── GET Loss Events/Claims ✓
        └── Claim payment tests ✓ (if payments exist)
        └── Service provider statement tests ✓ (if SP involved)
```

### Chain 4: Contact + Basket/Proposals (pre-issuance)
```
Contact exists
└── One or more Proposals exist in basket
    └── Validate Cart ✓
    └── Issue Policy List ✓
    └── POST /online-payment ✓
```

### Chain 5: Contact + Policy + Invoice
```
Contact exists
└── Policy exists and invoice has been generated
    └── Get Invoice ✓
    └── Get Payment Slip ✓
    └── Incoming Payment (BVR) ✓
```

---

## Reference data (must be pre-configured in the system)

The following reference/setup data must exist in the target environment before tests can run:

- **Products and product versions** (e.g. Membership 2024, ETI Travel V2, Legal Protection Driver)
- **Covers and cover types** per product
- **Cancellation and endorsement reasons**
- **Payment methods** (Cash, CC, BVR, Twint, PostFinance, Bank Transfer)
- **Service provider types and territories**
- **Entity types** (B2C, B2B)
- **Contact titles** (Mr, Mrs, Dr, Prof, etc.)
- **Family relationship types**
- **Contact sub-types** (VIP, TCS employee, etc.)
- **Sales channels / intermediaries**
- **GL mapping** (for SAP financial testing)
- **Language** (FR, DE, IT, EN — APIs support multi-language responses)

---

## Notes for non-regression testing in the migration context

- **Version delta**: The SaaS IDIT version is 4-5 major versions ahead. API response schemas may have **new fields** (acceptable) but must **not lose existing fields** (backwards compatibility is critical).
- **Three environments — QA → ACP → PROD**: Testing follows a promotion chain. QA is run first, then ACP (Acceptance/Pre-Production), then PROD. The collection must work across all three with no modifications — only the active Postman Environment file changes. The APIC hostname differs per environment; the API path structure is typically the same. Kibana traces come from PROD, so use their URL path as the canonical path pattern but never hardcode the PROD hostname into the collection.
- **ACE flows**: Some APIs are mediated by IBM ACE flows that transform messages. Response field names and structures may differ from raw IDIT responses — use traces to verify the ACE-transformed payload, not just the IDIT API spec.
- **MQ async**: Some integrations (SAP GL, document generation) are fire-and-forget via MQ. These cannot be directly tested with Postman HTTP requests; document them as manual verification steps or use polling on a status endpoint if available.
- **Correlation IDs**: Always send `X-Correlation-Id` (use `{{$guid}}`). In migration testing, this helps trace requests across APIC, ACE, IDIT, and external systems in Kibana.
- **Language**: Add `Accept-Language` header where APIs support multi-language responses.
