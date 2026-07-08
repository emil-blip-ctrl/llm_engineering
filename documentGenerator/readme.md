## Summary

`servicesIntegrationAssistanceCasesEventsMlogConsume` is an IBM App Connect Enterprise 12 application that consumes assistance case/service event messages from MQ, filters for FSM-relevant MLOGISTICS events, translates them into FSM request payloads, invokes an external FSM assistance-cases API, and publishes either a success/reference outcome or an error outcome to MQ topics.

The service exposes or uses these interfaces:

- **Inbound MQ consumption** from queue alias `A.SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2`
- **Outbound HTTP calls** to the FSM assistance-cases API
- **Outbound MQ topic publications** for:
  - success/reference outcomes
  - error outcomes

At a high level, the service:

1. Consumes JSON event messages from an MQ queue populated by a topic subscription.
2. Filters out events that are not relevant for FSM processing.
3. Determines whether the event represents a **CASE** or **SERVICE** operation and whether it should be sent as **POST** or **PUT**.
4. Translates the incoming business object into the FSM payload format using shared-library translators.
5. Sends the translated request to the external FSM API.
6. Publishes either a success/reference message or an error message to a configured MQ topic.

The implementation relies on shared libraries for:

- policy lookup
- HTTP/MQ encapsulation
- BOM-to-FSM translation
- common error handling

> **Payload note:** Input and output JSON shapes below are inferred from the visible ESQL and shared-subflow usage. No explicit schema/OpenAPI contract is included in the provided source, so treat examples as implementation-oriented rather than authoritative producer/consumer contracts.

---

## Project Overview

### ACE Project

Project name:

```text
servicesIntegrationAssistanceCasesEventsMlogConsume
```

Maven artifact / version, if visible:

```text
groupId:    ch.tcs.nip.ace
artifactId: services-integration-assistance-cases-events-mlog-consume
version:    1.0.0-SNAPSHOT
parent:     ch.tcs.nip.pom:tcs-pom-ace:1.0.10
```

Packaging is not explicitly declared in the provided `pom.xml`; ACE build is handled through the IBM Maven plugin.

### Main Components

| Component | Type | Purpose |
|---|---|---|
| `processEventFromQueueMlog.msgflow` | Message flow | Main orchestration flow: consume MQ message, filter, translate, call FSM, publish result/error |
| `IsMessageForMlog.esql` | Compute module | Business/event filter deciding whether the message should continue to FSM processing |
| `FindMethodAndData_Compute.esql` | Compute module | Determines request method (`POST`/`PUT`) and dataset (`CASE`/`SERVICE`) |
| `TranslateMessageForMlog.subflow` | Subflow | Routes to case vs service translation shared subflow |
| `SendMessageToMlog.subflow` | Subflow | Prepares outbound HTTP request and invokes shared HTTP call subflow |
| `SendMessageToMlog_Compute.esql` | Compute module | Builds HTTP headers, URL, and method |
| `processEventFromQueueMlog_ExtratBusinessIdentifiers.esql` | Compute module | Populates business identifiers into logging context |
| `processEventFromQueueMlog_ExtractIdentifiers.esql` | Compute module | Builds success/reference outcome publication payload |
| `processEventFromQueueMlog_ErrorHander.esql` | Compute module | Normalizes exception/backend errors into a JSON error structure |
| `processEventFromQueueMlog_PrepareError.esql` | Compute module | Builds error outcome publication payload |
| `resources/mq/install/01-install.mqs` | MQ script | Creates local queue, backout queue, alias queues, and topic subscription |

### Dependencies

| Dependency | Type | Usage |
|---|---|---|
| `SHLIB_PoliciesReader` | Shared library | Reads runtime policy values for endpoints, credentials, and topic names |
| `common-integration-shlib-encapsulate-calls` | Shared library | Provides MQ start, HTTP call, and MQ topic publication subflows |
| `SHLIB_TranslatorFsmBom` | Shared library | Provides BOM-to-FSM translation subflows for case and service payloads |
| `SHLIB_CommonErrorFunctions` | Shared library | Provides shared error-handling subflow(s) |
| `CommonHelper.*` | External/shared ESQL helper | Used to split semicolon-separated metadata into JSON arrays; source not visible in provided files |

Where shared-library internals are not provided, behavior below is based only on how those components are invoked.

---

## Entry Points / API Surface

Defined in:

```text
processEventFromQueueMlog.msgflow
resources/mq/install/01-install.mqs
```

Base entry mechanism:

```text
MQ topic subscription -> alias queue A.SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2
```

### Operations / Entry Points

| Method / Trigger | Path / Input | Implementation | Notes |
|---|---|---|---|
| MQ message | Queue alias `A.SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2` | `processEventFromQueueMlog.msgflow` | Queue is fed by subscription `SUB_SERVICES_MQ_MLOG_CASES_EVENTS_2` |
| Topic subscription | Topic object `SERVICES_MQ_ASSISTANCE_V2_CASES_EVENTS_TOPIC`, selector `FTserviceCharacteristics LIKE '%371001%'` | MQ infrastructure | Pre-filters inbound events before they reach ACE |

### MQ Infrastructure Visible in Source

| Resource | Definition | Notes |
|---|---|---|
| `SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2` | Local queue | Main inbound queue |
| `A.SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2` | Alias queue | Queue used by the flow |
| `SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2.BO` | Local backout queue | Backout storage |
| `A.SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2.BO` | Alias backout queue | Alias for backout queue |
| `SUB_SERVICES_MQ_MLOG_CASES_EVENTS_2` | Subscription | Delivers selected topic messages to the inbound queue |
| `BOTHRESH(3)` | Queue property | Matches the flow’s visible backout threshold setting |

### Expected Input Shape

The flow expects `InputRoot.JSON.Data` and also relies heavily on metadata copied into `Environment.Variables.MessageIn.MQRFH2.usr`.

An inferred payload shape is:

```json
{
  "Data": {
    "Id": "...",
    "InternalId": "...",
    "Active": true,
    "CaseReferenceList": {
      "Item": [
        {
          "Source": "MLOGISTICS",
          "Reference": "...",
          "Id": "..."
        }
      ]
    },
    "ServiceReferenceList": {
      "Item": [
        {
          "Source": "MLOGISTICS",
          "Reference": "...",
          "Id": "..."
        }
      ]
    },
    "ServiceCharacteristicList": {
      "Item": ["371001"]
    },
    "ServiceDeliveryList": {
      "Item": [
        {
          "Active": true,
          "InternalId": "...",
          "ServiceCharacteristicList": {
            "Item": ["371001"]
          },
          "ServiceReferenceList": {
            "Item": [
              {
                "Source": "MLOGISTICS",
                "Reference": "..."
              }
            ]
          }
        }
      ]
    }
  }
}
```

Important metadata fields expected in `Environment.Variables.MessageIn.MQRFH2.usr`:

| Field | Meaning / Usage |
|---|---|
| `UDeventInitiator` | Used to suppress self/loop processing for `FSM` and `MLOGISTICS` |
| `UDeventForwarder` | Used similarly to `UDeventInitiator` |
| `UDcontextsOfEvent` | Used to exclude unwanted contexts |
| `UDnaturesOfChanges` | Used to whitelist supported change types |
| `callerCode` | Copied into outcome `execution-context` |
| `originCallerCode` | Copied into outcome `execution-context` |

This MQRFH2-derived metadata is not built in this application; it is likely populated by the shared MQ start subflow.

---

## High-Level Architecture / Runtime Flow

```text
MQ Topic Subscription
  |
  v
A.SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2
  |
  v
cc_app_mq_start
  |
  +--> Catch ----------------------> ThrowCatchToRetry
  |
  +--> Output ---------------------> retrieveTechnicalError
  |                                   |
  |                                   v
  |                                ErrorHandler
  |                                   |
  |                                   v
  |                                PrepareError
  |                                   |
  |                                   v
  |                              cc_mq_topic_call
  |
  v
JSON
  |
  v
FilterFSM
  |
  +--> out1 -----------------------> NotForFSM
  |
  v
Find method_data
  |
  v
TranslateMessageForMlog
  |
  +--> Output1 --------------------> NotForFSM
  |
  +--> Output2 --------------------> ErrorHandler
  |
  v
ExtratBusinessIdentifiers
  |
  v
SendMessageToMlog
  |
  +--> Output ---------------------> BuildMessage
  |                                   |
  |                                   v
  |                              cc_mq_topic_call
  |
  +--> Output Error --------------> ErrorHandler
  |
  +--> ConnectionError -----------> ErrorHandler
```

### Runtime Overview

This application is an **asynchronous MQ consumer**, not a synchronous API flow. Messages are received from an MQ queue populated by a topic subscription. The first part of the flow normalizes the message into the JSON domain and decides whether the event is relevant for FSM processing.

If relevant, the flow classifies the message into one of two functional datasets:

- **CASE**
- **SERVICE**

It also determines whether the outbound FSM call should be a **POST** or **PUT**. The translated request is then sent to an external FSM API using a shared HTTP-calling subflow. The target URL and credentials are policy-driven.

The flow has three practical end states:

1. **Ignored / not for FSM**  
   The message is dropped into a terminal sink after monitoring.

2. **Processed successfully**  
   A success/reference outcome message is built and published to an MQ topic.

3. **Handled as error**  
   A normalized error structure is created, enriched with execution context, and published to an MQ error topic.

A separate catch/rethrow path is also wired from the shared MQ-start subflow, which is the part most clearly associated with retry/backout behavior.

---

## Operation Documentation

### Relevant Case Event Processing

**Purpose**

Send a qualifying case-related MLOGISTICS event to the FSM assistance-cases API and publish an outcome message.

**Flow**

```text
MQ -> JSON -> FilterFSM -> Find method_data -> TranslateBomToFsmCase
   -> SendMessageToMlog -> BuildMessage -> MQ topic publish
```

**Main behavior**

- Accepts the event only if:
  - it is not initiated/forwarded by `FSM` or `MLOGISTICS`
  - the context does not indicate `FIELD_SERVICE_NOT_CONCERNED` or `FIELD_SERVICE_UNAVAILABLE`
  - the change nature is one of the supported case/service change types
  - at least one active service delivery contains characteristic `371001`
- Determines `CASE` dataset and `POST` or `PUT`
- Translates the message with the shared `TranslateBomToFsmCase` subflow
- Sends the HTTP request to the FSM API
- On success, publishes a reference/outcome message
- On failure, publishes an error outcome message

**Pseudo-code**

```pseudo
on inbound event:
    if event is not eligible for FSM:
        stop

    if event represents case processing:
        determine method POST or PUT
        translate to FSM case payload
        call FSM API
        if call succeeds:
            publish success/reference outcome
        else:
            publish error outcome
```

### Relevant Service Event Processing

**Purpose**

Send a qualifying service-related MLOGISTICS event to the FSM assistance-cases API and publish an outcome message.

**Flow**

```text
MQ -> JSON -> FilterFSM -> Find method_data -> TranslateBomToFsmCaseService
   -> SendMessageToMlog -> BuildMessage -> MQ topic publish
```

**Distinct behavior compared with case processing**

- `FilterFSM` evaluates the **top-level** service delivery payload:
  - `InputRoot.JSON.Data.Active` must be true
  - `InputRoot.JSON.Data.ServiceCharacteristicList.Item[]` must contain `371001`
- Translator selection is driven by:

```text
$LocalEnvironment/Variables/Fsm/Request/Dataset = 'SERVICE'
```

- The outbound URL uses `/case/{referenceNumber}` rather than plain `/case`
- Success publication uses object type `QuoteLineItem`

**Pseudo-code**

```pseudo
on inbound event:
    if event is not eligible for FSM:
        stop

    if event represents service processing:
        determine method POST or PUT
        translate to FSM service payload
        call FSM API
        if call succeeds:
            publish success/reference outcome
        else:
            publish error outcome
```

### Non-Relevant / Alternate Path

**Purpose**

Terminate messages that should not be sent to FSM.

**Flow**

```text
FilterFSM out1 -> NotForFSM
TranslateMessageForMlog Output1 -> NotForFSM
```

**Main behavior**

- `FilterFSM` explicitly propagates non-eligible messages to terminal `out1`
- Shared translation subflows can also return an alternate path (`OutputAltern`), which is mapped to the same `NotForFSM` sink
- No downstream HTTP call or outcome publication occurs on this path

### Error Publication Path

**Purpose**

Convert technical, translation, or backend-call errors into a normalized JSON outcome and publish that outcome to the error topic.

**Flow**

```text
retrieveTechnicalError / Translate error / HTTP error
    -> ErrorHandler
    -> PrepareError
    -> cc_mq_topic_call
```

**Main behavior**

- Normalizes exceptions or backend HTTP errors into:

```text
JSON.Data.timestamp
JSON.Data.httpCode
JSON.Data.httpMessage
JSON.Data.moreInformation
```

- Repackages that normalized error into the final error-topic publication format
- Publishes to the topic name resolved from policy key `cases-outcomes-error`

---

## Core Components / Subflows

### `processEventFromQueueMlog`

File:

```text
processEventFromQueueMlog.msgflow
```

**Purpose**

Main orchestration flow for consuming MQ case/service events, calling FSM, and publishing outcome/error messages.

**Node-level flow**

```text
cc_app_mq_start
  -> ResetContentDescriptor(JSON)
  -> FilterFSM
     -> out1 -> NotForFSM
     -> out  -> Find method_data
               -> TranslateMessageForMlog
                  -> Output1 -> NotForFSM
                  -> Output2 -> ErrorHandler -> PrepareError -> cc_mq_topic_call
                  -> Output  -> ExtratBusinessIdentifiers
                              -> SendMessageToMlog
                                 -> Output         -> BuildMessage -> cc_mq_topic_call
                                 -> Output Error   -> ErrorHandler -> PrepareError -> cc_mq_topic_call
                                 -> ConnectionError-> ErrorHandler -> PrepareError -> cc_mq_topic_call

cc_app_mq_start Catch  -> ThrowCatchToRetry
cc_app_mq_start Output -> retrieveTechnicalError -> ErrorHandler -> PrepareError -> cc_mq_topic_call
```

**Detailed behavior**

- Starts from a shared MQ-start subflow configured with:
  - `queueName="A.SERVICES_MQ_INCOMING_MLOG_CASES_EVENTS_2"`
  - `BackoutThreshold="3"`
- Resets message domain to JSON before business logic starts
- Uses `FilterFSM` to eliminate events that should not reach FSM
- Uses `Find method_data` to determine request method and dataset and to seed environment/local-environment context
- Delegates payload conversion to shared translators via `TranslateMessageForMlog`
- Logs business identifiers before making the outbound call
- Sends the translated payload to the external FSM API
- Publishes either:
  - a success/reference outcome
  - or an error outcome

**Important runtime data**

| Variable / Tree | Usage |
|---|---|
| `Environment.Variables.MessageIn.MQRFH2.usr.*` | Source event metadata used for filtering and outcome publication |
| `OutputLocalEnvironment.Variables.Fsm.Request.Id` | Request identifier copied from input; likely used downstream or by shared components |
| `OutputLocalEnvironment.Variables.Fsm.Request.Method` | Controls outbound HTTP verb |
| `OutputLocalEnvironment.Variables.Fsm.Request.Dataset` | Controls translator selection and URL construction |
| `Environment.Variables.FSMRequest.InternalId` | Used in success/error outcome payloads |
| `Environment.Variables.FSMRequest.CaseId` | Used for case-origin references |
| `Environment.Variables.FSMRequest.ServiceId` | Used for service-origin references |
| `Environment.Variables.FSMCall.ObjectType` | `CASE` or `SERVICE`; reused in publication builders |
| `Environment.Variables.FSMCall.RequestMethod` | Reused in publication builders |
| `Environment.Variables.FSMCall.RequestURL` | Captured outbound URL; reused in publication builders |
| `OutputLocalEnvironment.Variables.Topic` | Topic destination for MQ publication subflow |
| `Environment.Variables.TCSLog.context.business-identifiers` | Monitoring/logging context |
| `Environment.Variables.Error.Info` | Normalized error payload for monitoring |

### `TranslateMessageForMlog`

File:

```text
TranslateMessageForMlog.subflow
```

**Purpose**

Selects the appropriate BOM-to-FSM translator based on whether the event is a case or a service.

**Node-level flow**

```text
Input
  -> ResetContentDescriptor(BLOB)
  -> Route(SendOnlyService)
       -> Match   -> TranslateBomToFsmCaseService -> Output / OutputAltern / OutputError
       -> default -> TranslateBomToFsmCase        -> toJson -> Output / OutputAltern / OutputError
```

**Detailed behavior**

- Resets the message domain to `BLOB` before translation
- Uses a Route node with filter:

```text
$LocalEnvironment/Variables/Fsm/Request/Dataset = 'SERVICE'
```

- `SERVICE` goes to `TranslateBomToFsmCaseService`
- All other values go to `TranslateBomToFsmCase`
- Both translators are external shared-library subflows; internal transformation logic is **not visible in the provided source**
- `OutputAltern` from either translator is treated as “not for FSM”
- `OutputError` from either translator is treated as an error and routed to centralized error handling

**Visible fact vs inference**

- **Fact:** Translator selection is dataset-driven.
- **Inference:** The translators likely construct the final JSON/BLOB payload required by the FSM API and may also populate environment data needed later.

### `SendMessageToMlog`

File:

```text
SendMessageToMlog.subflow
```

**Purpose**

Prepare the HTTP request, invoke the shared HTTP call subflow, and normalize success/error branches.

**Node-level flow**

```text
Input
  -> Prepare Request
  -> cc_http_async_call
       -> Response_Out -> toJson  -> Output
       -> Output1      -> toJson1 -> Output Error
       -> Output2      -> toJson1 -> Output Error
       -> Output       -> ConnectionError
       -> Output3      -> ConnectionError
```

**Detailed behavior**

- `Prepare Request` builds headers, URL, and HTTP method
- The outbound call is delegated to shared subflow `cc_http_async_call`
- Successful responses go through a JSON reset and return via `OutTerminal.Output`
- Error responses that still carry a body go through a JSON reset and return via `OutTerminal.Output Error`
- Connection/technical failures are routed via `OutTerminal.ConnectionError`

**Visible fact vs inference**

- **Fact:** The shared HTTP subflow is configured with:
  - `monitoring-api-name="external-api-fsm-assistance-cases"`
  - `monitoring-api-operation="case"`
  - `provider-name="FSM"`
- **Inference:** The terminal meanings (`Response_Out`, `Output1`, `Output2`, `Output`, `Output3`) are defined by the shared subflow and are not internally visible here.

---

## Key ESQL / Logic Analysis

### `IsMessageForMlog`

File:

```text
IsMessageForMlog.esql
```

**Purpose**

Business-level event filter that decides whether the message should continue to FSM processing.

**What it does**

- Reads event metadata from `Environment.Variables.MessageIn.MQRFH2.usr`
- Rejects events when:
  - `eventInitiator` is `FSM` or `MLOGISTICS`
  - `eventForwarder` is `FSM` or `MLOGISTICS`
  - `contextsOfEvent` contains `FIELD_SERVICE_NOT_CONCERNED`
  - `contextsOfEvent` contains `FIELD_SERVICE_UNAVAILABLE`
- Accepts only whitelisted change types, such as:
  - `MANUAL_TRIGGER_FSM`
  - `MANUAL_SEND_TRANSPORT`
  - `CASE_CREATED`
  - `CASE_*_CHANGED`
  - `CASE_CANCELLATION`
  - `SERVICE_CREATED`
  - `SERVICE_UPDATED`
  - `SERVICE_ACKNOWLEDGED`
  - `SERVICE_STATUS_CHANGED`
- Distinguishes between:
  - case-style payloads using `CaseReferenceList`
  - service-style payloads using `ServiceReferenceList`
- Requires characteristic `371001` in:
  - an active service delivery for case payloads
  - the active top-level service payload for service events

**Pseudo-code**

```pseudo
read eventInitiator, eventForwarder, contextsOfEvent, naturesOfChanges

if initiator is FSM or MLOGISTICS:
    reject
if forwarder is FSM or MLOGISTICS:
    reject
if contexts include FIELD_SERVICE_NOT_CONCERNED or FIELD_SERVICE_UNAVAILABLE:
    reject

if naturesOfChanges contains one of the supported values:
    if payload looks like case:
        for each active service delivery:
            if any service characteristic contains 371001:
                return true
    else if payload looks like service and payload is active:
        if any top-level service characteristic contains 371001:
            return true

propagate to out1
return false
```

**Notes**

- `isCase()` sets `Environment.Variables.case.ref`, but that value is not read again in the provided source.
- Non-relevant messages are not thrown as errors; they are explicitly diverted to terminal `out1`.
- The MQ subscription already filters on `FTserviceCharacteristics LIKE '%371001%'`; this ESQL adds a second, payload-based eligibility check.

### `processEventFromQueueMlog_FindMethodAndData`

File:

```text
FindMethodAndData_Compute.esql
```

**Purpose**

Determine the outbound HTTP method and dataset, and seed shared runtime context used by later nodes.

**What it does**

- Copies message and local environment
- Scans `CaseReferenceList.Item[]` and `ServiceReferenceList.Item[]`
- Sets:
  - `Method` = `POST` or `PUT`
  - `Dataset` = `CASE` or `SERVICE`
- Persists request context into:
  - `OutputLocalEnvironment.Variables.Fsm.Request.*`
  - `Environment.Variables.FSMRequest.*`
  - `Environment.Variables.FSMCall.*`

**Pseudo-code**

```pseudo
method  = ''
dataset = ''

for each case reference:
    if source is MLOGISTICS and no reference exists:
        method  = POST
        dataset = CASE
        FSMRequest.CaseId = case reference Id
    else if source is MLOGISTICS and reference exists:
        method  = PUT
        dataset = CASE

for each service reference:
    if source is MLOGISTICS and no reference exists:
        method  = POST
        dataset = SERVICE
        FSMRequest.ServiceId = service reference Id
    else if source is MLOGISTICS and reference exists:
        method  = PUT
        dataset = SERVICE

LocalEnvironment.Fsm.Request.Id      = InputRoot.JSON.Data.Id
LocalEnvironment.Fsm.Request.Method  = method
LocalEnvironment.Fsm.Request.Dataset = dataset

FSMRequest.InternalId   = InputRoot.JSON.Data.InternalId
FSMCall.ObjectType      = dataset
FSMCall.RequestMethod   = method
```

**Notes**

- If both case and service references are present, the later service loop can overwrite the earlier case decision.
- There is a visible inconsistency in the code:
  - it checks `CaseReferenceList.Source.Reference`
  - and `ServiceReferenceList.Source.Reference`
  - while the rest of the project generally uses `CaseReferenceList.Reference` / `ServiceReferenceList.Reference`
- Because of that inconsistency, the POST/PUT decision should be reviewed carefully against the real payload shape.

### `SendMessageToMlog_Compute`

File:

```text
SendMessageToMlog_Compute.esql
```

**Purpose**

Prepare outbound HTTP headers, determine the request URL, and set the HTTP method.

**What it does**

- Copies message headers and local environment
- Sets outbound headers:
  - `Content-Type: application/json; charset=utf-8`
  - `X-IBM-Client-id`
  - `X-IBM-Client-secret`
  - `X-Global-Transaction-Id`
  - `X-Caller-Code`
  - `Fsm-Client-Id`
- Copies `InputRoot.JSON.Data` into `OutputRoot.JSON.Data`
- Builds endpoint URL from policy values
- Stores final request URL into local environment and environment

**Pseudo-code**

```pseudo
copy headers
copy local environment

set Content-Type
set X-IBM-Client-id from AceAppEsbCredentialsPolicy.client_id
set X-IBM-Client-secret from AceAppEsbCredentialsPolicy.client_secret
set X-Global-Transaction-Id from Environment
set X-Caller-Code = ApplicationLabel

copy JSON.Data from input to output

endpointUrl = GlobalEndpointsPolicy.apic-host
endpointUrl += ApicEndPoints.path-external-api-fsm-assistance-cases

if dataset == CASE:
    endpointUrl += '/case'
else:
    endpointUrl += '/case/' + Environment.ESB.ESBEnvelope.userDefined.request.event.referenceNumber

set Fsm-Client-Id from FsmCredentialsPolicy.fsm-client-id
set LocalEnvironment.Destination.HTTP.RequestURL = endpointUrl
set LocalEnvironment.Destination.HTTP.RequestLine.Method = Fsm.Request.Method

Environment.FSMCall.RequestURL = endpointUrl
```

**Notes**

- The service URL for `SERVICE` depends on `Environment.ESB.ESBEnvelope.userDefined.request.event.referenceNumber`.
- That field is **not set anywhere in the provided project source**, so it is likely supplied by a shared translator or other shared component.
- The HTTP call is visibly directed toward an FSM API, even though many artifact names include `Mlog`.

### `processEventFromQueueMlog_ExtractIdentifiers`

File:

```text
processEventFromQueueMlog_ExtractIdentifiers.esql
```

**Purpose**

Build the success/reference publication payload sent to the MQ outcome topic.

**What it does**

- Sets topic destination from policy key `cases-outcomes-references`
- Builds `event-received` with:
  - `naturesOfChanges[]`
  - `contextsOfEvent[]`
  - `eventInitiator`
  - `eventForwarder`
- Builds `execution-context` with:
  - transaction/correlation ids
  - current timestamp
  - HTTP status code if available
  - caller/origin caller code
  - request method
  - `target_system = 'MLOGISTICS'`
  - `target_url`
- Builds `external-references` entries for success cases

**Pseudo-code**

```pseudo
set Topic = policy('cases-outcomes-references')

build event-received arrays from MQRFH2 usr fields
build execution-context from environment and HTTP status data

find caseRef from CaseReferenceList where Source = MLOGISTICS
find serviceRef from ServiceReferenceList where Source = MLOGISTICS

if method == POST and objectType == CASE:
    external-references[1].target_object_type = CASE
    external-references[1].target_object_id   = caseRef
    external-references[1].error_code         = ''
    external-references[1].error_message      = ''
    if FSMRequest.CaseId exists:
        external-references[1].origin_record_id = FSMRequest.CaseId
    else:
        external-references[1].origin_object_type = CASE
        external-references[1].origin_object_id   = FSMRequest.InternalId

else if method == POST and objectType == SERVICE:
    external-references[1].target_object_type = QuoteLineItem
    external-references[1].target_object_id   = serviceRef
    external-references[1].error_code         = ''
    external-references[1].error_message      = ''
    if FSMRequest.ServiceId exists:
        external-references[1].origin_record_id = FSMRequest.ServiceId
    else:
        external-references[1].origin_object_type = QuoteLineItem
        external-references[1].origin_object_id   = FSMRequest.InternalId
```

**Notes**

- Only **POST** success paths have explicit external-reference construction in visible code.
- There is **no explicit PUT success branch** here.
- Visible code observation: in the service-reference loop, the assignment is:

```text
SET caseRef = ServiceReferenceList.Reference;
```

  rather than setting `serviceRef`. As written, `serviceRef` may remain empty.
- The code sets `target_system = 'MLOGISTICS'` while the actual outbound HTTP target is the FSM API. That is a visible naming/data-model choice in this implementation.

### `processEventFromQueueMlog_PrepareError`

File:

```text
processEventFromQueueMlog_PrepareError.esql
```

**Purpose**

Build the final error publication payload sent to the MQ error topic.

**What it does**

- Sets topic destination from policy key `cases-outcomes-error`
- Rebuilds the same `event-received` and `execution-context` sections used in success outcomes
- Composes an `errorDescription` from normalized error fields:
  - `httpMessage`
  - `moreInformation`
- Populates `external-references[1]` differently depending on method/object type

**Pseudo-code**

```pseudo
set Topic = policy('cases-outcomes-error')

errorDescription = 'Message: ' + httpMessage + '-Details: ' + moreInformation

build event-received
build execution-context

if POST CASE:
    origin_object_type = CASE
    origin_object_id   = FSMRequest.InternalId
    error_code         = WrittenDestination.HTTP.StatusCode
    error_message      = errorDescription

if POST SERVICE:
    origin_object_type = QuoteLineItem
    origin_object_id   = FSMRequest.InternalId
    error_code         = WrittenDestination.HTTP.StatusCode
    error_message      = errorDescription

if PUT CASE:
    origin_record_id   = FSMRequest.CaseId
    error_code         = WrittenDestination.HTTP.StatusCode
    error_message      = errorDescription

if PUT SERVICE:
    origin_record_id   = FSMRequest.ServiceId
    error_code         = WrittenDestination.HTTP.StatusCode
    error_message      = errorDescription
```

**Notes**

- Error codes come from `InputLocalEnvironment.WrittenDestination.HTTP.StatusCode`.
- That value is expected to be set by the shared HTTP subflow; its exact population is not visible in the provided source.
- Error publication is more complete than success publication for PUT paths.

### `processEventFromQueueMlog_ErrorHander`

File:

```text
processEventFromQueueMlog_ErrorHander.esql
```

**Purpose**

Normalize exceptions or backend HTTP errors into a common JSON error payload.

**What it does**

- Sets response content type to JSON
- Handles three situations:
  1. exception list present
  2. backend HTTP response header present
  3. fallback unknown error
- Produces:

```text
OutputRoot.JSON.Data.timestamp
OutputRoot.JSON.Data.httpCode
OutputRoot.JSON.Data.httpMessage
OutputRoot.JSON.Data.moreInformation
```

- Stores the final structure in `Environment.Variables.Error.Info`

**Pseudo-code**

```pseudo
if InputExceptionList is present:
    code = 500
    extract deepest exception numbers/text/inserts
    message = 'ACETECHERR001: <number> - <text>' or fallback
    details = stacktrace or 'Internal Server Error.'

else if HTTPResponseHeader is present:
    if BLOB body exists:
        body = BLOB
    else if JSON.Data exists:
        body = asBitstream(JSON.Data)
    code    = X-Original-HTTP-Status-Code
    message = 'Error when requesting backend API ' + X-Original-HTTP-Status-Line
    details = body as character

else:
    code = 500
    message = 'unknown error'
    details = 'unknown error'

write normalized JSON error payload
store payload in Environment.Variables.Error.Info
```

**Notes**

- `GetException()` walks down the nested exception tree via repeated `LASTCHILD`, so it captures the visible deepest exception chain rather than traversing every sibling branch.
- This module is the central normalization point before `PrepareError` converts the error into the final outcome-topic structure.

### `processEventFromQueueMlog_ExtratBusinessIdentifiers`

File:

```text
processEventFromQueueMlog_ExtratBusinessIdentifiers.esql
```

**Purpose**

Populate business identifiers into `Environment.Variables.TCSLog.context` for monitoring/logging.

**What it does**

- Writes:
  - `CaseId = InputRoot.JSON.Data.InternalId`
- Appends:
  - `CaseReference = <Source>=<Reference>`
  - `ServiceId = <InternalId>`
  - `ServiceReference = <Reference>=<Source>`

This module does not visibly affect business payload routing; it enriches logging context.

---

## Branching / Propagation / Batch Processing

### Branching behavior

- `FilterFSM` uses explicit `PROPAGATE TO TERMINAL 'out1'` for non-relevant events.
- `TranslateMessageForMlog` uses a Route node:
  - `SERVICE` -> service translator
  - default -> case translator
- `SendMessageToMlog` branches shared HTTP outcomes into:
  - success
  - output error
  - connection error

### Propagation behavior

- The only explicit ESQL `PROPAGATE` in the provided source is in `IsMessageForMlog`.
- That propagation is used to terminate non-relevant messages cleanly without throwing an error.
- No visible `PROPAGATE`-based fan-out or multi-message generation is implemented.

### Batch handling

No batching logic is visible in the provided source.

---

## Error Handling and Monitoring

### Error Handling

Visible error paths include:

1. **MQ start / technical startup path**
   - Shared `cc_app_mq_start` additional `Output` terminal goes to `retrieveTechnicalError` and then to error publication.
   - Exact semantics of this terminal are not visible; it is clearly treated as an error path.

2. **Catch / retry path**
   - Shared `cc_app_mq_start` `Catch` terminal is wired to a Throw node (`ThrowCatchToRetry`).
   - This is the clearest retry/backout-related path in the flow.

3. **Translation errors**
   - `TranslateMessageForMlog` `Output2` routes directly to `ErrorHandler`.

4. **HTTP/business/backend errors**
   - `SendMessageToMlog` `Output Error` routes to `ErrorHandler`.

5. **Connection/technical call failures**
   - `SendMessageToMlog` `ConnectionError` routes to `ErrorHandler`.

6. **Handled non-relevant events**
   - Routed to `NotForFSM`
   - Not treated as errors

### Runtime consequence of handled vs retried failures

A key visible behavior is:

- **Catch path** -> rethrow -> likely retry/backout behavior
- **Translation/HTTP/connection errors** -> normalized and published to error topic -> flow ends normally

So not all failures are retried. Many are treated as business/technical outcomes and consumed after publication.

### Monitoring

Key visible monitoring events:

| Node / Component | Event | Notes |
|---|---|---|
| `ThrowCatchToRetry` | `CATCH: ThrowCatch.terminal.in` | Captures exception list on catch/rethrow path |
| `NotForFSM` | `Message NotForFSM` | Indicates message was intentionally ignored |
| `Find method_data` | `Find method_data.InTerminal` / `OutTerminal` / `FAIL` | Includes selected method and dataset on success |
| `ExtratBusinessIdentifiers` | `SUP: LOG invoice identifiers` | Logs business identifiers; label appears reused |
| `BuildMessage` | `SUP: END Process event to FSM` | End of success processing before publish |
| `ErrorHandler` | `START: Build exception` / `INFO: END: Build exception` / `FAIL` | Centralized error normalization monitoring |
| `Prepare Request` | `START/END/FAIL` | Outbound HTTP request preparation |
| `SendOnlyService` route | `SendOnlyService is TRUE/FALSE` | Shows translator selection branch |

---

## Configuration, Policies, and External Dependencies

### Policies / Config

| Key / Config | Used By | Purpose |
|---|---|---|
| `{AceAppEsbCredentialsPolicies}:AceAppEsbCredentialsPolicy / client_id` | `SendMessageToMlog_Compute` | APIC/client header |
| `{AceAppEsbCredentialsPolicies}:AceAppEsbCredentialsPolicy / client_secret` | `SendMessageToMlog_Compute` | APIC/client header |
| `{services-integration-policies-credentials}:FsmCredentialsPolicy / fsm-client-id` | `SendMessageToMlog_Compute` | FSM-specific header |
| `{GlobalEndpointsPolicies}:GlobalEndpointsPolicy / apic-host` | `SendMessageToMlog_Compute` | Base API host |
| `{services-integration-policies-endpoints}:ApicEndPoints / path-external-api-fsm-assistance-cases` | `SendMessageToMlog_Compute` | FSM assistance API base path |
| `{services-integration-policies-endpoints}:TopicMqEndPoints / cases-outcomes-references` | `processEventFromQueueMlog_ExtractIdentifiers` | Success/reference topic |
| `{services-integration-policies-endpoints}:TopicMqEndPoints / cases-outcomes-error` | `processEventFromQueueMlog_PrepareError` | Error topic |

### Shared Libraries / External Components

| Component | Source | Visible Usage | Notes |
|---|---|---|---|
| `cc_app_mq_start.subflow` | `common-integration-shlib-encapsulate-calls` | MQ consumption entry point | Internal behavior not visible |
| `cc_http_async_call.subflow` | `common-integration-shlib-encapsulate-calls` | Outbound HTTP invocation | Terminal semantics inferred from wiring only |
| `cc_mq_topic_call.subflow` | `common-integration-shlib-encapsulate-calls` | MQ topic publication | Likely publishes to `LocalEnvironment.Variables.Topic`; internals not visible |
| `TranslateBomToFsmCase.subflow` | `SHLIB_TranslatorFsmBom` | Case payload translation | Internal mapping not visible |
| `TranslateBomToFsmCaseService.subflow` | `SHLIB_TranslatorFsmBom` | Service payload translation | Internal mapping not visible |
| `CommonError/manageOtherError.subflow` | `SHLIB_CommonErrorFunctions` | Technical error extraction before centralized error builder | Internal behavior not visible |
| `Shlib_PoliciesReader.gestionPolicy` | `SHLIB_PoliciesReader` | Policy lookup | Core configuration dependency |
| `CommonHelper.transformStringToListDefinedSeparator` | External/shared helper | Converts `;`-separated metadata strings to JSON arrays | Implementation not visible |

### Environment Overrides

Files exist for:

```text
resources/overrides/ACP.properties
resources/overrides/DEV.properties
resources/overrides/PRD.properties
resources/overrides/QA.properties
```

They are empty in the provided source.

### MQ Scripts

- Install script is populated and defines queues/subscription.
- Uninstall script is empty in the provided source.

---

## HTTP or Message Outputs

### Outbound HTTP Request

**Target**

Policy-driven FSM assistance-cases API.

**Method**

From:

```text
LocalEnvironment.Variables.Fsm.Request.Method
```

Expected values from visible code:

```text
POST or PUT
```

**URL construction**

```text
<apic-host><path-external-api-fsm-assistance-cases>/case
```

or

```text
<apic-host><path-external-api-fsm-assistance-cases>/case/<referenceNumber>
```

**Headers**

| Header | Source |
|---|---|
| `Content-Type` | Hardcoded |
| `X-IBM-Client-id` | Policy |
| `X-IBM-Client-secret` | Policy |
| `X-Global-Transaction-Id` | Environment |
| `X-Caller-Code` | `ApplicationLabel` |
| `Fsm-Client-Id` | Policy |

### Success Output

Because this is an MQ consumer, there is **no synchronous reply** to a caller. The “success output” is an MQ topic publication.

**Destination**

Policy key:

```text
cases-outcomes-references
```

**Inferred shape**

```json
{
  "Data": {
    "event-received": {
      "naturesOfChanges": ["..."],
      "contextsOfEvent": ["..."],
      "eventInitiator": "...",
      "eventForwarder": "..."
    },
    "execution-context": {
      "global_transaction_id": "...",
      "x_correlation_id": "...",
      "datetime": "2024-01-01T12:00:00",
      "http_status_code": 200,
      "x_caller_code": "...",
      "x_origin_caller_code": "...",
      "request_method": "POST",
      "target_system": "MLOGISTICS",
      "target_url": "..."
    },
    "external-references": [
      {
        "target_object_type": "CASE",
        "target_object_id": "...",
        "origin_record_id": "...",
        "error_code": "",
        "error_message": ""
      }
    ]
  }
}
```

**Important notes**

- Success reference-building is only explicit for visible `POST` branches.
- `SERVICE` success messages use `target_object_type = "QuoteLineItem"`.
- For `SERVICE` success, the visible code contains an apparent inconsistency that may leave `target_object_id` empty unless another component supplies it.

### Error Output

Again, this is an MQ topic publication, not an HTTP response to an inbound caller.

**Destination**

Policy key:

```text
cases-outcomes-error
```

**Intermediate normalized error shape produced by `ErrorHandler`**

```json
{
  "Data": {
    "timestamp": "2024-01-01T12:00:00",
    "httpCode": "500",
    "httpMessage": "ACETECHERR001: ...",
    "moreInformation": "..."
  }
}
```

**Final published error-outcome shape**

```json
{
  "Data": {
    "event-received": {
      "naturesOfChanges": ["..."],
      "contextsOfEvent": ["..."],
      "eventInitiator": "...",
      "eventForwarder": "..."
    },
    "execution-context": {
      "global_transaction_id": "...",
      "x_correlation_id": "...",
      "datetime": "2024-01-01T12:00:00",
      "http_status_code": 500,
      "x_caller_code": "...",
      "x_origin_caller_code": "...",
      "request_method": "PUT",
      "target_system": "MLOGISTICS",
      "target_url": "..."
    },
    "external-references": [
      {
        "origin_record_id": "...",
        "error_code": "500",
        "error_message": "Message: ...-Details: ..."
      }
    ]
  }
}
```

---

## End-to-End Pseudo-code

```pseudo
on incoming MQ event:
    start shared MQ consumption
    if catch/retry condition occurs in MQ-start shared logic:
        throw to preserve retry/backout behavior

    parse payload as JSON

    if event initiator or forwarder is FSM or MLOGISTICS:
        stop as NotForFSM

    if contexts contain FIELD_SERVICE_NOT_CONCERNED or FIELD_SERVICE_UNAVAILABLE:
        stop as NotForFSM

    if naturesOfChanges does not contain a supported change type:
        stop as NotForFSM

    if payload is case:
        require at least one active service delivery with characteristic 371001
    else if payload is service:
        require active top-level service with characteristic 371001
    else:
        stop as NotForFSM

    determine outbound method and dataset:
        CASE or SERVICE
        POST or PUT

    route to translator:
        SERVICE -> shared service translator
        otherwise -> shared case translator

    if translator returns alternate/not-applicable:
        stop as NotForFSM

    if translator returns error:
        normalize error
        build error outcome
        publish to error topic
        stop

    enrich monitoring business identifiers

    prepare outbound HTTP request:
        set headers from policies and environment
        build URL from policy + dataset
        set HTTP verb from earlier classification

    call shared FSM HTTP subflow

    if HTTP call succeeds:
        build success/reference outcome
        publish to references topic
        stop

    if HTTP call returns backend error or connection error:
        normalize error
        build error outcome
        publish to error topic
        stop
```

### Notable Code Observations for Developers

These are direct observations from the provided source and are worth reviewing during maintenance:

1. **POST/PUT decision logic appears inconsistent**
   - `FindMethodAndData_Compute.esql` checks `Source.Reference`
   - most other code reads `Reference` directly from the reference item

2. **Service success reference extraction appears inconsistent**
   - `processEventFromQueueMlog_ExtractIdentifiers.esql` assigns service reference into `caseRef`, not `serviceRef`

3. **Success publication is explicitly modeled only for POST paths**
   - No visible explicit success external-reference mapping for PUT

4. **Service URL depends on a value not set in this application**
   - `Environment.ESB.ESBEnvelope.userDefined.request.event.referenceNumber`
   - likely supplied by shared translation or another shared component

These may all be intentional in the wider solution, but they are not fully explained by the provided project source alone.