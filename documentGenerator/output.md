## Summary

`insurance-claims-integration-send-mail` is an IBM App Connect Enterprise 12 application that consumes MQ messages related to insurance claim processing and sends email notifications through a downstream asynchronous email service.

The service exposes two queue-driven entry points:

- `A.CLAIMSSENDMAIL.PROCESS` — standard claim email notification flow
- `A.CLAIMSSENDMAILALIS.PROCESS` — ALIS-specific claim email notification flow

At a high level, the application:

1. Receives JSON messages from MQ.
2. Extracts the business payload from a shared wrapper format.
3. Stores key values in `Environment.Variables` for template selection, routing, and logging.
4. Builds one or more email payloads from policy-driven templates and/or supplied HTML content.
5. Calls a support email async HTTP endpoint.
6. On technical failure, parses/classifies the error and forwards the current message to a back-office MQ queue.

The implementation relies on:

- `SHLIB_PoliciesReader` for policy lookup functions
- `common-integration-shlib-wrap-message` for shared message wrapper extraction/building
- MQ policies and endpoint policies referenced from policy projects

> **Important note on inferred payloads:** the input/output shapes below are inferred from ESQL and message flow logic only. In ACE solutions, wrapper subflows, shared libraries, and upstream/downstream gateways can alter the effective contract. Treat the examples here as implementation-oriented approximations, not authoritative external API schemas.

---

## Project Overview

### ACE Project

Project name:

```text
insurance-claims-integration-send-mail
```

Maven artifact / packaging / version:

```text
groupId:    ch.tcs.nip.ace
artifactId: insurance-claims-integration-send-mail
version:    1.0.9-SNAPSHOT
packaging:  pom
parent:     ch.tcs.nip.pom:tcs-pom-ace:1.0.10
```

### Main Components

| Component | Type | Purpose |
|---|---|---|
| `SendClaimEmailNotification.msgflow` | Message flow | Consumes standard claim email requests from MQ and sends client/back-office email notifications |
| `SendClaimAlisEmailNotification.msgflow` | Message flow | Consumes ALIS claim email requests and may generate multiple emails from a single message |
| `SetEnvironment.esql` | ESQL | Extracts inbound fields into `Environment.Variables` and initializes logging context |
| `BuildEmailMessage.esql` | ESQL | Builds outbound email payloads for client, ALIS, and back-office scenarios |
| `PrepareCallToSendMail.esql` | ESQL | Prepares HTTP headers, URL, and request body for the downstream email service |
| `BuildFailureMessage.esql` | ESQL | Converts exception-list failures into normalized error information |
| `BuildErrorMessage.esql` | ESQL | Parses downstream HTTP error payloads and raises a user exception |
| `BuildError.esql` | ESQL | Forwards the current message to BO handling and updates error logging context |
| `resources/mq/install/01-install.mqs` | MQ script | Defines local and alias queues used by the application |
| `resources/overrides/*.properties` | Override files | Configures additional instances for `SendClaimEmailNotification` |

### Dependencies

| Dependency | Type | Visible Usage |
|---|---|---|
| `SHLIB_PoliciesReader` | Shared library | Used via `PATH Shlib_PoliciesReader;` for policy lookup functions such as `getPolicyProperty`, `getPolicyPropertyWithOutError`, and likely `gestionPolicy` |
| `common-integration-shlib-wrap-message` | Shared library | Provides `messageExtract` and `messageBuild` subflows |
| `{GlobalMQPolicies}:RemoteMQPolicies` | MQ policy | Used by MQ Input / MQ Output nodes |
| `{common-integration-policies-endpoints}:AceEndpointsPolicy` | Endpoint policy | Supplies host `ace-host-support` for downstream email service |
| `{CommonInsurancePolicies}:CommonInsurancePolicy` | Policy | Supplies path `basepath-support-it-integration-email-async` |
| `{InsuranceClaimsSendMailPolicies}:InsuranceClaimsSendMailPolicy` | Policy | Supplies email templates, recipients, links, and flags |

Where internals are not visible in the provided source, they are described only by observable usage.

---

## Entry Points / Message Surface

Defined in:

```text
SendClaimEmailNotification.msgflow
SendClaimAlisEmailNotification.msgflow
resources/mq/install/01-install.mqs
```

Base entry mechanism:

```text
MQInput on alias queues using {GlobalMQPolicies}:RemoteMQPolicies
```

### Operations / Entry Points

| Trigger | Queue / Input | Implementation | Notes |
|---|---|---|---|
| MQ message | `A.CLAIMSSENDMAIL.PROCESS` | `SendClaimEmailNotification.msgflow` | Standard claim notification flow; may send customer email and optionally a BO email |
| MQ message | `A.CLAIMSSENDMAILALIS.PROCESS` | `SendClaimAlisEmailNotification.msgflow` | ALIS flow; may generate up to two outbound email requests from one inbound message |

### Inferred Input Shape — Standard Claim Flow

Derived from `SetEnvironment.Main`.

```json
{
  "email": "customer@example.com",
  "claimNumber": "123456",
  "language": "FR",
  "error": false,
  "errorHttpCode": "400",
  "errorHttpMessage": "Some upstream error",
  "numberOfDocuments": 2,
  "documentListGUUID": "guid-value",
  "documentList": [
    {
      "Item": [
        { "type": "file-name", "value-code": "invoice.pdf" },
        { "type": "document-type", "value-code": "INVOICE" }
      ]
    }
  ],
  "keyValuesOfOnlineForm": "k1=v1,k2=v2",
  "policyNumber": "P-001",
  "personalReference": "PR-001"
}
```

Important fields:

| Field | Meaning |
|---|---|
| `email` | Customer email address |
| `claimNumber` | Claim reference inserted into email templates |
| `language` | Suffix for policy template keys |
| `error` | Business/process error flag, not just mail-delivery failure |
| `errorHttpCode` / `errorHttpMessage` | Upstream error details included in BO email body |
| `documentListGUUID` | Document list identifier used to build an EDM link |
| `documentList[]` | Optional document metadata used in BO email text |
| `keyValuesOfOnlineForm` | Raw online form data summary inserted into BO email |
| `policyNumber` / `personalReference` | Included in BO email |

### Inferred Input Shape — ALIS Flow

Derived from `SetEnvironmentAlis.Main`.

```json
{
  "email": "customer@example.com",
  "claimNumber": "123456",
  "emailContent": "PGh0bWw+Li4uPC9odG1sPg==",
  "language": "FR",
  "error": false,
  "sendMailBusiness": true,
  "sendMailClient": true,
  "initConsumerName": "TCSCH",
  "countClaimContact": 1,
  "numberOfDocuments": 3,
  "policyNumber": "P-001",
  "personalReference": "PR-001"
}
```

Important fields:

| Field | Meaning |
|---|---|
| `emailContent` | Base64-encoded HTML used for the ALIS business email |
| `sendMailBusiness` | Controls generation of the business-facing ALIS email |
| `sendMailClient` | Controls generation of the customer-facing ALIS email |
| `initConsumerName` | Used to select consumer-specific policy messages |
| `countClaimContact` | Affects which success text is inserted into the ALIS business email |

---

## High-Level Architecture / Runtime Flow

### Standard Claim Flow

```text
MQ Input (A.CLAIMSSENDMAIL.PROCESS)
  |
  v
messageExtract   [shared library]
  |
  v
SetEnvironment
  |
  v
Flow Order
  |
  +--> first
  |      |
  |      v
  |    BuildEmailMessageForClient
  |      |
  |      v
  |    PrepareCallToSendMail
  |      |
  |      v
  |    HTTP Request
  |
  +--> second
         |
         v
       BuildEmailMessageForBackOffice   [only propagates when input error = TRUE]
         |
         v
       PrepareCallToSendMail
         |
         v
       HTTP Request

HTTP Request.error   -> BuildErrorMessage   -> THROW USER EXCEPTION
HTTP Request.failure -> BuildFailureMessage -> THROW USER EXCEPTION

Unhandled exception
  |
  v
MQ Input catch
  |
  v
BuildError
  |
  +--> out  -> MQ Output (A.CLAIMSSENDMAIL.PROCESS.BO)
  |
  +--> out1 -> PassThrough
```

### ALIS Flow

```text
MQ Input (A.CLAIMSSENDMAILALIS.PROCESS)
  |
  v
messageExtract   [shared library]
  |
  v
SetEnvironmentAlis
  |
  v
BuildEmailMessageAlis
  |
  +--> PROPAGATE business email   [if sendMailBusiness = TRUE]
  |      |
  |      v
  |    PrepareCallToSendMail
  |      |
  |      v
  |    HTTP Request
  |
  +--> PROPAGATE client email     [if sendMailClient = TRUE]
         |
         v
       PrepareCallToSendMail
         |
         v
       HTTP Request

HTTP Request.error   -> BuildErrorMessage   -> THROW USER EXCEPTION
HTTP Request.failure -> BuildFailureMessage -> THROW USER EXCEPTION

Unhandled exception
  |
  v
MQ Input catch
  |
  v
BuildError
  |
  +--> out  -> messageBuild [shared library] -> MQ Output (A.CLAIMSSENDMAIL.PROCESS.BO)
  |
  +--> out1 -> PassThrough
```

### Runtime Overview

Both flows are asynchronous MQ-to-HTTP integrations. No direct reply is returned to the original producer.

The common execution pattern is:

- receive a JSON MQ message,
- extract the business payload via shared wrapper logic,
- populate `Environment.Variables` for business values and log context,
- build an outbound email request body,
- call a downstream support email service over HTTP.

The two flows differ mainly in email generation strategy:

- **Standard flow** uses `FlowOrder` to send the customer email first and then, only when the inbound `error` flag is true, send an additional back-office email.
- **ALIS flow** uses explicit `PROPAGATE` calls from ESQL to emit zero, one, or two email requests from a single input message.

On technical failures, both flows normalize the failure into `Environment.Variables.Error`, then rely on the MQ Input catch path to trigger BO handling.

---

## Operation-by-Operation Documentation

## Standard Claim Notification

**Purpose**

Send a claim-related email to the customer, and when the inbound message indicates a business/process error, also send a plain-text back-office notification.

**Flow**

```text
MQ Input -> messageExtract -> SetEnvironment -> FlowOrder
  first  -> BuildEmailMessageForClient -> PrepareCallToSendMail -> HTTP Request
  second -> BuildEmailMessageForBackOffice -> PrepareCallToSendMail -> HTTP Request
```

**Main behavior**

- Reads customer and claim fields from the inbound JSON.
- Builds the customer email body from policy templates.
- Chooses between normal and delay template based on policy `DELAY_FLAG`.
- If inbound `error = TRUE`, uses an error template for the customer email and also generates a BO email.
- BO email contains detailed operational information: policy, personal reference, upstream error details, correlation ID, document information, and form key-values.
- HTTP success responses are not processed further in the visible flow.
- HTTP errors/failures are escalated and eventually routed to BO queue handling.

**Pseudo-code**

```pseudo
on message from A.CLAIMSSENDMAIL.PROCESS:
    extract wrapped payload
    copy key fields to Environment

    send customer email:
        if inbound error = false:
            if policy DELAY_FLAG = "FALSE":
                use template CLAIM_<language>
            else:
                use template DELAY_CLAIM_<language>
            replace CLAIM_NUMBER in body
        else:
            use template ERROR_<language>

        derive subject from HTML <title>
        call downstream email service

    then send BO email:
        if inbound error = true:
            build plain text email to BO_EMAILADDRESS
            include policy/personal reference/upstream error/correlation/documents/form values
            call downstream email service
        else:
            do nothing

    if downstream HTTP error/failure occurs:
        normalize error
        throw exception to MQ Input catch
        forward current message to BO queue
```

**Execution nuance**

`FlowOrder` makes the two sends sequential. If the first send fails, the second branch will not complete. If the first succeeds and the second fails, there is no visible compensation or rollback.

---

## ALIS Claim Notification

**Purpose**

Generate ALIS-related notification emails. A single inbound MQ message can trigger:

- a business-facing email,
- a customer-facing email,
- or both.

**Flow**

```text
MQ Input -> messageExtract -> SetEnvironmentAlis -> BuildEmailMessageAlis
  -> (0..2 PROPAGATE calls) -> PrepareCallToSendMail -> HTTP Request
```

**Main behavior**

- Decodes a base64 HTML template for the business email.
- Selects the business recipient from policy, not from the input email field.
- Replaces placeholders such as `CLAIM_NUMBER`, `LIEN`, `MESSAGE`, and `NB_PIECE_JOINTE`.
- Selects consumer-specific success/error texts using `initConsumerName` and `language`.
- If `countClaimContact > 1`, switches to an alternative “no closed” message.
- Sends a customer email from a separate policy template when `sendMailClient = TRUE`.
- Uses `PROPAGATE DELETE NONE` to emit each outbound email request.

**Pseudo-code**

```pseudo
on message from A.CLAIMSSENDMAILALIS.PROCESS:
    extract wrapped payload
    copy key fields to Environment

    if sendMailBusiness = true:
        if inbound error = true:
            claimNumberForMail = policy CLAIM_ALIS_FAIL_<language>
        else:
            claimNumberForMail = actual claim number

        businessTemplate = base64decode(emailContent)
        subject = HTML <title> with CLAIM_NUMBER replaced
        body = businessTemplate with CLAIM_NUMBER replaced

        if inbound error = false:
            link = policy CLAIM_ALIS_LINK with CLAIM_NUMBER replaced
            prefix = policy CLAIM_ALIS_MESSAGE_BEFORE_LINK_<consumer>_<language>
            body = replace LIEN with prefix + link

            message = policy CLAIM_ALIS_SUCCESS_MESSAGE_<consumer>_<language>
            if countClaimContact > 1:
                message = policy CLAIM_ALIS_NOCLOSED_MESSAGE_<consumer>_<language> or previous message
            body = replace MESSAGE with message
        else:
            body = replace LIEN with empty string
            message = policy CLAIM_ALIS_ERROR_MESSAGE_<consumer>_<language>
            if message is empty:
                message = fallback policy CLAIM_ALIS_ERROR_MESSAGE_TCSCH_<language>
            body = replace MESSAGE with message

        body = replace NB_PIECE_JOINTE with numberOfDocuments
        send to policy recipient CLAIM_ALIS_MAIL_<language>

    if sendMailClient = true:
        template = policy CLAIM_ALIS_<language>
        subject = HTML <title>
        body = replace CLAIM_NUMBER with actual claim number
        send to input email

    if any downstream HTTP error/failure occurs:
        normalize error
        throw exception to MQ Input catch
        route message to BO handling
```

**Execution nuance**

The visible design is sequential and propagation-based. Earlier propagated emails are attempted before later ones. A failure during one propagated path is likely to prevent subsequent propagations from completing.

---

## Core Subflows / Components

## `messageExtract`

File:

```text
common-integration-shlib-wrap-message/messageExtract.subflow
```

**Purpose**

Shared wrapper extraction before business logic starts.

**Visible usage**

- Used at the start of both flows.
- Output is compatible with subsequent ESQL that expects `InputRoot.JSON.Data...`.

**What is not visible**

The internals are not provided. It likely unwraps a common envelope and preserves log/trace context in `LocalEnvironment`, but that behavior is inferred from naming and downstream usage.

---

## `messageBuild`

File:

```text
common-integration-shlib-wrap-message/messageBuild.subflow
```

**Purpose**

Shared wrapper build logic on the ALIS error path before MQ output.

**Visible usage**

- Used only in `SendClaimAlisEmailNotification.msgflow` between `BuildError` and `MQ Output`.

**What is not visible**

The internals are not provided. It likely rebuilds a common wrapper format required by downstream MQ consumers, but that is inferred only from naming.

---

## `SetEnvironment` / `SetEnvironmentAlis`

File:

```text
SetEnvironment.esql
```

**Purpose**

Extracts inbound business fields, initializes `Environment.Variables`, and copies monitoring/log context from `InputLocalEnvironment`.

**Important runtime data**

| Variable / Tree | Usage |
|---|---|
| `Environment.Variables.email` | Customer email |
| `Environment.Variables.claimNumber` | Claim reference |
| `Environment.Variables.language` | Policy/template language suffix |
| `Environment.Variables.error` | Business error indicator |
| `Environment.Variables.XCorrelationID` | Global correlation ID for downstream header and logging |
| `Environment.Variables.trackID` | Parent transaction ID for monitoring |
| `Environment.Variables.TCSLog.context` | Logging context copied from inbound local environment |
| `Environment.Variables.In.XCallerCode` | Original caller code preserved for later error logging |
| `Environment.Variables.sendMailBuisness` | ALIS business-email flag |
| `Environment.Variables.sendMailClient` | ALIS client-email flag |
| `Environment.Variables.initConsumerName` | ALIS consumer-specific template selection |
| `Environment.Variables.countClaimContact` | ALIS message variant selector |

**Notes**

- `SetEnvironment` sets source/target logging context to `CMP05625 -> CMP05541`.
- `SetEnvironmentAlis` does the same for ALIS processing.
- The ALIS code stores the flag in `sendMailBuisness` internally; the inbound field is `sendMailBusiness`.

---

## `PrepareCallToSendMail`

File:

```text
PrepareCallToSendMail.esql
```

**Purpose**

Constructs the HTTP request to the downstream email service.

**Node-level flow**

```text
Input email JSON -> set HTTP headers -> resolve URL from policies -> copy JSON body -> downstream HTTP Request
```

**Detailed behavior**

- Sets:
  - `Content-Type = application/json`
  - `Accept = */*`
  - `X-Global-Transaction-Id = Environment.Variables.XCorrelationID`
  - `X-Caller-Code = insurance-claims-integration-send-mail`
  - `X-Origin-Caller-Code = Environment.Variables.TCSLog.context."origin-caller"`
- Resolves URL from:
  - host: `ace-host-support`
  - path: `basepath-support-it-integration-email-async`
- Sets:
  - `OutputLocalEnvironment.Destination.HTTP.RequestURL`
  - `OutputLocalEnvironment.Destination.HTTP.RequestLine.Method = 'POST'`
- Copies `InputRoot.JSON.Data` to `OutputRoot.JSON.Data`.
- Updates logging context for outbound call.

**Visible external call target construction**

```text
RequestURL = policy(AceEndpointsPolicy.ace-host-support)
           + policy(CommonInsurancePolicy.basepath-support-it-integration-email-async)
```

---

## Key ESQL / Logic Analysis

## `BuildEmailMessageForClient`

File:

```text
BuildEmailMessage.esql
```

**Purpose**

Builds the standard customer-facing claim email.

**What it does**

- Sets fixed sender `_no_reply_@tcs.ch`.
- Sends to `Environment.Variables.email`.
- Selects body template from `InsuranceClaimsSendMailPolicy`.
- If inbound `error = FALSE`:
  - checks policy `DELAY_FLAG`
  - uses `CLAIM_<language>` only when `DELAY_FLAG = 'FALSE'`
  - otherwise uses `DELAY_CLAIM_<language>`
- If inbound `error = TRUE`:
  - uses `ERROR_<language>`
- Replaces placeholder `CLAIM_NUMBER`.
- Extracts subject from the HTML `<title>...</title>`.
- Sets `contentType = text/html;charset=utf-8`.

**Pseudo-code**

```pseudo
from = "_no_reply_@tcs.ch"
to = Environment.email

if Environment.error = false:
    delayFlag = policy DELAY_FLAG
    if delayFlag = "FALSE":
        bodyTemplate = policy CLAIM_<language>
    else:
        bodyTemplate = policy DELAY_CLAIM_<language>
    body = replace(bodyTemplate, "CLAIM_NUMBER", claimNumber)
else:
    bodyTemplate = policy ERROR_<language>
    body = bodyTemplate

subject = extractTitle(bodyTemplate)
contentType = "text/html;charset=utf-8"
```

**Important implementation note**

Any `DELAY_FLAG` value other than literal `'FALSE'` leads to the delayed template path.

---

## `BuildEmailMessageAlis`

File:

```text
BuildEmailMessage.esql
```

**Purpose**

Builds ALIS email messages and emits multiple outputs when required.

**What it does**

- Initializes sender as `_no_reply_@tcs.ch`.
- Business email branch:
  - only if `sendMailBuisness = TRUE`
  - sends to policy-defined recipient `CLAIM_ALIS_MAIL_<language>`
  - decodes HTML from base64 input `emailContent`
  - extracts subject from `<title>`
  - on error:
    - replaces claim number with policy value `CLAIM_ALIS_FAIL_<language>`
    - inserts consumer-specific error message or fallback
    - removes `LIEN`
  - on success:
    - builds ALIS link from policy `CLAIM_ALIS_LINK`
    - inserts consumer-specific success message
    - if `countClaimContact > 1`, switches to `CLAIM_ALIS_NOCLOSED_MESSAGE_<consumer>_<language>` when available
  - replaces `NB_PIECE_JOINTE` with `numberOfDocuments`
  - `PROPAGATE DELETE NONE`
- Client email branch:
  - only if `sendMailClient = TRUE`
  - uses policy template `CLAIM_ALIS_<language>`
  - sends to the inbound customer email
  - replaces `CLAIM_NUMBER`
  - `PROPAGATE DELETE NONE`
- Returns `FALSE`, so only explicit propagations are emitted.

**Pseudo-code**

```pseudo
set from = "_no_reply_@tcs.ch"

if sendMailBusiness:
    if error:
        claimNumber = policy CLAIM_ALIS_FAIL_<language>

    bodyTemplate = base64decode(emailContent)
    to = policy CLAIM_ALIS_MAIL_<language>
    subject = extractTitle(bodyTemplate) with CLAIM_NUMBER replaced
    body = bodyTemplate with CLAIM_NUMBER replaced

    if not error:
        link = policy CLAIM_ALIS_LINK with CLAIM_NUMBER replaced
        prefix = policy CLAIM_ALIS_MESSAGE_BEFORE_LINK_<consumer>_<language>
        body = replace(body, "LIEN", prefix + link)

        message = policy CLAIM_ALIS_SUCCESS_MESSAGE_<consumer>_<language>
        if countClaimContact > 1:
            message = policy CLAIM_ALIS_NOCLOSED_MESSAGE_<consumer>_<language> or previous message
        body = replace(body, "MESSAGE", message)
    else:
        body = replace(body, "LIEN", "")
        message = policy CLAIM_ALIS_ERROR_MESSAGE_<consumer>_<language>
        if message = "":
            message = policy CLAIM_ALIS_ERROR_MESSAGE_TCSCH_<language>
        body = replace(body, "MESSAGE", message)

    body = replace(body, "NB_PIECE_JOINTE", numberOfDocuments)
    propagate current OutputRoot

if sendMailClient:
    to = input email
    bodyTemplate = policy CLAIM_ALIS_<language>
    subject = extractTitle(bodyTemplate)
    body = replace(bodyTemplate, "CLAIM_NUMBER", actual claimNumber)
    propagate current OutputRoot

return false
```

**Notes**

- This is the main multi-message generator in the application.
- The business recipient is policy-driven, not message-driven.
- The customer email still uses the real claim number even if the business email uses a failure replacement string.

---

## `BuildEmailMessageForBackOffice`

File:

```text
BuildEmailMessage.esql
```

**Purpose**

Builds a plain-text operational email to back-office recipients when the inbound message indicates a business/process error.

**What it does**

- Only returns output when `Environment.Variables.error = TRUE`.
- Sends to policy `BO_EMAILADDRESS`.
- Subject includes:
  - `personalReference`
  - customer `email`
- Body includes:
  - `language`
  - `policyNumber`
  - IDIT/upstream error status and title
  - ELK/correlation ID
  - document GUID
  - optional EDM link using `EDM_BASEPATH`
  - number of uploaded documents
  - per-document name/type list
  - key-values of the online form

**Pseudo-code**

```pseudo
if error = true:
    from = "_no_reply_@tcs.ch"
    to = policy BO_EMAILADDRESS
    subject = 'Error with online form of customer "<personalReference>, <email>"'

    body = plain text summary
    add language
    add policy number
    add IDIT status/title
    add correlation ID
    add document GUID

    if document GUID exists:
        add EDM_BASEPATH + "/claim?guid=" + document GUID

    add number of uploaded documents

    if documentList exists:
        for each document:
            extract file-name and document-type from Item[]
            append to body

    if keyValuesOfOnlineForm exists:
        append formatted key-values
    else:
        append "no values"

    contentType = "text/plain;charset=utf-8"
    return true
else:
    return false
```

**Notes**

- `gestionPolicy(..., 'EDM_BASEPATH')` is referenced, but its implementation is not visible. It is likely supplied by the policy-reader shared library.
- The document structure is inferred from field access patterns only.

---

## `BuildFailureMessage` and `BuildErrorMessage`

Files:

```text
BuildFailureMessage.esql
BuildErrorMessage.esql
```

**Purpose**

Normalize technical failures from the downstream HTTP call into `Environment.Variables.Error`, then deliberately rethrow to the top-level catch path.

**`BuildFailureMessage` behavior**

- Walks to the deepest nested `RecoverableException`.
- If a `SocketTimeoutException` exists:
  - sets `httpCode = 504`
  - sets message to `ACE : Gateway Timeout`
  - sets more info to max-response-time exceeded
- Otherwise:
  - sets `httpCode = 500`
  - builds `httpMessage = 'ACE : <Catalog>: <Number>'`
  - concatenates exception text and inserts into `moreInformation`
- Throws `USER EXCEPTION`.

**`BuildErrorMessage` behavior**

- If `InputRoot.BLOB.BLOB` exists:
  - parses it as JSON
  - expects fields `httpCode`, `httpMessage`, `moreInformation`
  - strips prefix `'ACE : '` from `httpCode`
  - stores values into `Environment.Variables.Error`
- Throws `USER EXCEPTION`.

**Notes**

- `statusCode` and `statusLine` are set in `BuildFailureMessage`, but are not used elsewhere in the provided source.
- If the error terminal payload has no BLOB body, `BuildErrorMessage` still throws; the later `BuildError` module then falls back to default logging values.

---

## `BuildError`

File:

```text
BuildError.esql
```

**Purpose**

Top-level catch handler that forwards the current message to BO handling and separately emits error logging context.

**What it does**

1. Copies `InputRoot` to `OutputRoot`.
2. Explicitly propagates to default `out`.
3. Updates `Environment.Variables.TCSLog.context` with error details.
4. Explicitly propagates to `out1`.
5. Returns `FALSE`.

**Pseudo-code**

```pseudo
OutputRoot = InputRoot
propagate to out with current message

set log severity = ERROR
set caller-code = original inbound caller
set target-url = UNKNOWN
set error-message = httpMessage + ". " + moreInformation or "Internal Server Error"
set error-code = httpCode or "500"

propagate to out1
return false
```

**Important runtime consequence**

The BO MQ propagation happens **before** the error logging context is enriched. Therefore, the explicitly forwarded MQ message is the current message tree as-is; it is not turned into a serialized error object by this module.

---

## Branching / Propagation / Multi-message Behavior

### Branching behavior

**Standard flow**

- Uses a `FlowOrder` node after `SetEnvironment`.
- `first` terminal: customer email.
- `second` terminal: back-office email.
- Both branches converge on the same `PrepareCallToSendMail` and `HTTP Request` path.

**ALIS flow**

- No `FlowOrder`.
- Multi-send is implemented inside `BuildEmailMessageAlis` with explicit `PROPAGATE DELETE NONE`.

### Propagation behavior

**`BuildEmailMessageAlis`**

- Emits a message for each enabled email branch.
- Returns `FALSE`, suppressing automatic propagation.
- Can produce:
  - 0 messages
  - 1 message
  - 2 messages

**`BuildError`**

- Emits two explicit propagations:
  - `out`: BO queue path
  - `out1`: monitor/log path ending in `PassThrough`

### Batch handling

No batch collection or flush logic is visible in the provided source.

---

## Error Handling and Monitoring

### Error Handling

#### 1. Business/process error in inbound payload

Visible trigger:

```text
Environment.Variables.error = TRUE
```

Effects:

- Standard customer email uses `ERROR_<language>` template.
- Standard flow also sends a BO operational email.
- ALIS business email uses error-specific content/message substitutions.

This is distinct from technical HTTP delivery failure.

#### 2. Downstream HTTP error terminal

Path:

```text
HTTP Request.error -> BuildErrorMessage -> THROW USER EXCEPTION -> MQ Input catch -> BuildError
```

Visible behavior:

- Expects a JSON error payload with:
  - `httpCode`
  - `httpMessage`
  - `moreInformation`
- Persists these values in `Environment.Variables.Error`.

#### 3. Downstream HTTP failure terminal

Path:

```text
HTTP Request.failure -> BuildFailureMessage -> THROW USER EXCEPTION -> MQ Input catch -> BuildError
```

Visible behavior:

- Maps socket timeout to HTTP-style 504.
- Maps all other failures to 500 and records catalog/number/text.

#### 4. BO routing on catch

Visible outputs:

- `SendClaimEmailNotification` sends catch-path output directly to `A.CLAIMSSENDMAIL.PROCESS.BO`.
- `SendClaimAlisEmailNotification` sends catch-path output to `messageBuild` and then to `A.CLAIMSSENDMAIL.PROCESS.BO`.

> Fact visible in source: the ALIS flow’s explicit MQ Output also targets `A.CLAIMSSENDMAIL.PROCESS.BO`, not the ALIS-specific BO alias queue.

### Monitoring

| Node / Component | Event | Notes |
|---|---|---|
| `SendClaimAlisEmailNotification.MQ Input` | `Start Send Mail Notification ALIS` | Uses `$Root/MQRFH2/usr/gtid` as global transaction correlator |
| `SetEnvironment` / `SetEnvironmentAlis` | `SUP: RECEIVE message to send email` | Emits TCS log context and correlation IDs |
| `PrepareCallToSendMail` | `SUP: SEND email message` / `Send email message` | Visible around downstream HTTP call |
| `HTTP Request` | `Error received` | On error terminal |
| `BuildFailureMessage` | `FAIL: Catch exception` | Includes `$ExceptionList` as application data |
| `BuildError` | `SUP: RECEIVE fail response` | Emitted on `out1`, after error logging context is populated |
| `MQ Output` | `Send message to BO` | On BO queue path |

---

## Configuration, Policies, and External Dependencies

### Policies / Config

| Key / Config | Used By | Purpose |
|---|---|---|
| `ace-host-support` | `PrepareCallToSendMail` | Host of support email endpoint |
| `basepath-support-it-integration-email-async` | `PrepareCallToSendMail` | Path of support email endpoint |
| `DELAY_FLAG` | `BuildEmailMessageForClient` | Chooses normal vs delayed claim template |
| `CLAIM_<lang>` | `BuildEmailMessageForClient` | Normal customer template |
| `DELAY_CLAIM_<lang>` | `BuildEmailMessageForClient` | Delayed customer template |
| `ERROR_<lang>` | `BuildEmailMessageForClient` | Error customer template |
| `CLAIM_ALIS_MAIL_<lang>` | `BuildEmailMessageAlis` | Business recipient for ALIS |
| `CLAIM_ALIS_LINK` | `BuildEmailMessageAlis` | Link inserted into ALIS business email |
| `CLAIM_ALIS_MESSAGE_BEFORE_LINK_<consumer>_<lang>` | `BuildEmailMessageAlis` | Text prefix before ALIS link |
| `CLAIM_ALIS_SUCCESS_MESSAGE_<consumer>_<lang>` | `BuildEmailMessageAlis` | Success text |
| `CLAIM_ALIS_NOCLOSED_MESSAGE_<consumer>_<lang>` | `BuildEmailMessageAlis` | Alternative success text when `countClaimContact > 1` |
| `CLAIM_ALIS_ERROR_MESSAGE_<consumer>_<lang>` | `BuildEmailMessageAlis` | Error text |
| `CLAIM_ALIS_ERROR_MESSAGE_TCSCH_<lang>` | `BuildEmailMessageAlis` | Fallback error text |
| `CLAIM_ALIS_<lang>` | `BuildEmailMessageAlis` | Customer-facing ALIS template |
| `CLAIM_ALIS_FAIL_<lang>` | `BuildEmailMessageAlis` | Replacement value used in error case |
| `BO_EMAILADDRESS` | `BuildEmailMessageForBackOffice` | BO recipient |
| `EDM_BASEPATH` | `BuildEmailMessageForBackOffice` | Base path for optional document link |

### Shared Libraries / External Components

| Component | Source | Visible Usage | Notes |
|---|---|---|---|
| `getPolicyProperty` | `SHLIB_PoliciesReader` | Reads policy values throughout ESQL | Implementation not visible |
| `getPolicyPropertyWithOutError` | `SHLIB_PoliciesReader` | Fallback lookup in ALIS error messaging | Implementation not visible |
| `gestionPolicy` | likely `SHLIB_PoliciesReader` | Reads `EDM_BASEPATH` | Exact implementation not visible |
| `messageExtract` | `common-integration-shlib-wrap-message` | Shared input wrapper extraction | Internals not visible |
| `messageBuild` | `common-integration-shlib-wrap-message` | Shared wrapper build on ALIS BO path | Internals not visible |

### MQ Objects

Visible in `resources/mq/install/01-install.mqs`:

| Queue | Type | Purpose |
|---|---|---|
| `L.CLAIMSSENDMAIL.PROCESS` | Local | Standard processing queue |
| `A.CLAIMSSENDMAIL.PROCESS` | Alias | Standard input alias used by flow |
| `L.CLAIMSSENDMAIL.PROCESS.BO` | Local | Standard BO queue |
| `A.CLAIMSSENDMAIL.PROCESS.BO` | Alias | Standard BO alias used by flow |
| `L.CLAIMSSENDMAILALIS.PROCESS` | Local | ALIS processing queue |
| `A.CLAIMSSENDMAILALIS.PROCESS` | Alias | ALIS input alias used by flow |
| `L.CLAIMSSENDMAILALIS.PROCESS.BO` | Local | ALIS BO queue |
| `A.CLAIMSSENDMAILALIS.PROCESS.BO` | Alias | ALIS BO alias |

Additional visible MQ settings:

- `L.CLAIMSSENDMAIL.PROCESS` uses `BOQNAME(A.CLAIMSSENDMAIL.PROCESS.BO)`
- `L.CLAIMSSENDMAILALIS.PROCESS` uses `BOQNAME(A.CLAIMSSENDMAILALIS.PROCESS.BO)` and `BOTHRESH(3)`

### Overrides

Visible overrides:

```text
SendClaimEmailNotification#additionalInstances = 1
```

Present for:

- `ACP`
- `DEV`
- `QA`
- `PRD`

No equivalent override is visible for `SendClaimAlisEmailNotification` in the provided source.

---

## HTTP / Message Outputs

### Downstream HTTP Request

**Method**

```text
POST
```

**Headers**

```text
Content-Type: application/json
Accept: */*
X-Global-Transaction-Id: <Environment.Variables.XCorrelationID>
X-Caller-Code: insurance-claims-integration-send-mail
X-Origin-Caller-Code: <Environment.Variables.TCSLog.context.origin-caller>
```

**Success request body shape**

Inferred from the email-building ESQL:

```json
{
  "from": "_no_reply_@tcs.ch",
  "to": "recipient@example.com",
  "subject": "Mail subject",
  "contentType": "text/html;charset=utf-8",
  "body": "<html>...</html>"
}
```

Back-office emails use:

```json
{
  "from": "_no_reply_@tcs.ch",
  "to": "bo@example.com",
  "subject": "Error with online form of customer \"...\"",
  "contentType": "text/plain;charset=utf-8",
  "body": "Language: ...\nPolicy: ..."
}
```

### HTTP Success Handling

Visible behavior:

```text
No success processing is wired after the HTTP Request out terminal.
```

So the downstream success response is effectively ignored by the visible flow.

### HTTP Error Payload Expected by `BuildErrorMessage`

```json
{
  "httpCode": "ACE : 500",
  "httpMessage": "ACE : Some error",
  "moreInformation": "Detailed message"
}
```

This shape is inferred from parsing logic only.

### MQ Error Output

Visible BO output target:

```text
A.CLAIMSSENDMAIL.PROCESS.BO
```

Used explicitly by:

- `SendClaimEmailNotification`
- `SendClaimAlisEmailNotification`

Exact BO message envelope/content is not fully visible because:

- `BuildError` forwards the current message as-is,
- ALIS BO routing also passes through shared `messageBuild`,
- wrapper subflow internals are not provided.

---

## End-to-End Pseudo-code

```pseudo
on incoming MQ message:
    identify flow by input queue

    run shared messageExtract
    initialize Environment variables and logging context

    if standard claim flow:
        build customer email from policy template
        call email async HTTP service

        if inbound error flag = true:
            build BO plain-text email
            call email async HTTP service

    else if ALIS flow:
        if sendMailBusiness = true:
            decode input base64 HTML
            enrich with policy-driven link/message content
            send business email

        if sendMailClient = true:
            build customer ALIS email from policy template
            send client email

    on downstream HTTP error terminal:
        parse returned error JSON into Environment.Error
        throw user exception

    on downstream HTTP failure terminal:
        map timeout to 504 or other failures to 500
        populate Environment.Error
        throw user exception

    on top-level catch:
        forward current message to BO queue path
        update error logging context
        emit monitoring/log branch
```

