# IDIT Documentation — Compressed Text Extracts

Extracted from:
- `NIS-190526-063841.pdf` (1,152 pages) — IDIT documentation repository
- `NIS-200526-Stories.pdf` (6,487 pages) — Full user stories

## Files

### doc-core.txt.gz
Core API and domain documentation. Sections included:
- **Interfaces & APIs** (pages 541–660): full API catalogue — SIX, BVR, SAP GL, Core entities GET/PUT/POST, Policy/Proposal/Endorsement services, Get Invoice, Get Payment Slip, GET Loss Events/Claims, HUI (Validate Cart, Reject Proposal, Issue Policies, Generate Payment Slip, Get Portfolio, Get Reference Data, Get Buyable Products, Get Product Details), Marketing Campaign APIs, Salesforce notifications, SAP Service Providers, Generic APIs, Contact Migration, SCIM, SAP Exchange Rate, Salesforce Deeplinks, SAP Outgoing Claim Payments, Salesforce Contact management
- **Domain Setup** (pages 9–82): Policy Setup, Contact Setup, Billing Setup, Claims Setup — reference tables, field definitions
- **Claims Functional** (pages 152–219): Service Providers, Loss Notice View, Claim Recoveries, Create Loss Event, Catastrophe Event, Claim Payments, Claim Handling, Claim Reserves, Claims Online, Claim Task Management
- **Sales / Policy Lifecycle** (pages 220–340): New business, Endorsements, Shopping Cart, Marketing Campaign, Discount Management, Contact
- **Billing** (pages 414–502): Incoming Payments, Payments Management, Dunning, Commissioning, Credits/Refunds, Transactions, Pay Debt, Invoicing

### products.txt.gz
All product definitions (pages 789–1115):
- TCS Legal Protection Private, Driver, Internet, Building, Cyber
- TCS Emergency Protection
- TCS Membership Bike (SOC Velo)
- TCS Camping Membership
- TCS Membership
- TCS ETI Travel
- TCS Home
- TCS Bike Insurance
- TCS Car Mobility Package
- TCS Company Card
- TCS Card Assistance

### stories-recent.txt.gz
Most recent 200 pages of user stories from NIS-200526-Stories.pdf.
Contains detailed API enhancement stories with field-level specifications,
error handling, and business rules for: Policy API, Proposal API, Claims API,
Contact API, Invoice API, Basket/Cart API, Get Product Details, Payment Slip,
SCIM, Marketing Campaign API, and more.

## Decompression

```bash
cd /tmp
gunzip -c /path/to/idit-docs/doc-core.txt.gz > idit-doc-core.txt
gunzip -c /path/to/idit-docs/products.txt.gz > idit-products.txt
gunzip -c /path/to/idit-docs/stories-recent.txt.gz > idit-stories.txt
```

Then search or read sections as needed:
```bash
grep -n -i "<keyword>" idit-doc-core.txt | head -30
# Note line numbers, then read context around them
sed -n '<line_start>,<line_end>p' idit-doc-core.txt
```
