## Summary

`exchange-client-integration-online-service-access-requests-v2` is an IBM App Connect Enterprise 12 REST service that accepts online assistance SMS link requests and orchestrates a multi-step backend process to send the requester an SMS containing an access link.

The service exposes:

- `GET /exchange-clients/v2/online-service-access-requests/health`
- `POST /exchange-clients/v2/online-service-access-requests/sms-online-assistance-request`

At a high level, the POST operation:

1. Logs the inbound request and technical context.
2. Validates required caller metadata and request fields.
3. Loads policy-driven configuration based on the request `contact-reason`.
4. Calls a JWT generation API to obtain an access token.
5. Builds a redirect URL and attempts to shorten it.
6. Calls a forge-text API to generate the final SMS text.
7. Calls an SMS API to send the message.
8. Returns a synthetic acknowledgment payload to the caller, or a standardized JSON error if the orchestration fails.

The implementation relies heavily on:

- external policy projects
- the shared library `SHLIB_PoliciesReader`
- reusable HTTP helper compute modules in `utils.esql`
- a centralized HTTP error builder subflow

> The request/response examples below describe what ACE itself appears to consume and produce. In real deployments, APIC or another gateway may sit in front of ACE, so the end-user-visible contract can differ from the raw ACE flow behavior.

---

## Project Overview

### ACE Project

Project name:

```text
exchange-client-integration-online-service-access-requests-v2
```

Maven artifact / packaging / version:

```text
groupId:    ch.tcs.nip.ace
artifactId: exchange-client-integration-online-service-access-requests-v2
version:    2.0.1-SNAPSHOT
packaging:  pom
parent:     ch.tcs.nip.pom:tcs-pom-ace:1.0.9
```

### Main Components

| Component | Type | Purpose |
|---|---|---|
| `restapi.descriptor` | REST API descriptor | Maps REST operations to implementation subflows |
| `swagger.json` | OpenAPI/Swagger 2.0 | Active API contract used by the REST descriptor |
| `gen/OnlineServiceAccessRequestsV2.msgflow` | Generated message flow | Main HTTP entry flow routing REST operations to implementation subflows |
| `health.subflow` | Subflow | Simple health-check response |
| `postSmsOnlineAssistanceRequest.subflow` | Subflow | Main orchestration for SMS online assistance requests |
| `callJwtGenService.subflow` | Subflow | Calls JWT generation API |
| `callUrlShortenerService.subflow` | Subflow | Calls URL shortener API; failure is tolerated |
| `callForgeTextService.subflow` | Subflow | Calls forge-text API to generate SMS content |
| `callSendSmsService.subflow` | Subflow | Calls SMS API to send the SMS |
| `build_http_error.subflow` | Subflow | Builds standardized HTTP JSON error response |
| `utils.esql` | Shared ESQL utilities | HTTP response/error helper compute modules |
| `globalFunctions.esql` | Shared ESQL functions | Exception parsing, policy access helpers, string normalization |

### Dependencies

| Dependency | Type | Usage |
|---|---|---|
| `exchange-integration-policies-credentials` | Policy project | Credentials for URL shortener and forge-text; visible through policy names used in ESQL |
| `exchange-integration-policies-endpoints` | Policy project | Endpoint path configuration for downstream APIs |
| `exchange-integration-policies-properties-digitalintake` | Policy project | Brand / contact-reason specific configuration |
| `SHLIB_PoliciesReader` | Shared library | Reads single or all properties from policy projects |

### Visible vs Inferred Dependencies

- **Directly visible in code**: policy reads via `Shlib_PoliciesReader.getPolicyPropertyWithOutError(...)` and `Shlib_PoliciesReader.getAllPolicyProperties(...)`.
- **Not visible in provided source**: internal implementation of `SHLIB_PoliciesReader`, actual deployed policy values, APIC-side mediation, and downstream API schemas beyond fields inferred from usage.

---

## Entry Points / API Surface

Defined in:

```text
restapi.descriptor
swagger.json
gen/OnlineServiceAccessRequestsV2.msgflow
```

Base path / entry mechanism:

```text
HTTPS REST input on /exchange-clients/v2/online-service-access-requests*
```

The generated flow uses an HTTP Input node with:

- `useHTTPS=true`
- message domain `JSON`

### Operations / Entry Points

| Method | Path | Implementation | Notes |
|---|---|---|---|
| `GET` | `/health` | `health.subflow` | Simple liveness response |
| `POST` | `/sms-online-assistance-request` | `postSmsOnlineAssistanceRequest.subflow` | Main SMS online assistance orchestration |

### Active vs Legacy API Definition

- **Active contract**: `swagger.json`
- **Legacy file present**: `swagger-v1.json`

`restapi.descriptor` points to `swagger.json`, so `swagger-v1.json` appears historical and is not the active contract in the provided source.

### Expected Input Shape

From `swagger.json` and confirmed by ESQL usage, the POST request is expected to contain at least:

```json
{
  "service-access-info": {
    "number-initiating": "+41800316900",
    "number-contacted": "+41765459694",
    "language": "fr",
    "contact-type": "outbound",
    "contact-reason": "ONLINEASSY",
    "physical-person": {
      "firstname": "John",
      "lastname": "Doe"
    }
  },
  "request-type": "OA_LINK_REQUEST"
}
```

Important headers used by the flow:

| Header | Usage |
|---|---|
| `X-Caller-Code` | Required by custom validation |
| `X-Global-Transaction-Id` | Stored and propagated to downstream services and error responses |
| `X-Origin-Caller-Code` | Optional; propagated downstream when present |

Important request fields used by the orchestration:

| Field | Meaning / Usage |
|---|---|
| `service-access-info.number-contacted` | Used for JWT generation and SMS dispatch |
| `service-access-info.language` | Used in redirect URL construction and forge-text request |
| `service-access-info.contact-reason` | Drives policy selection and SMS sender code |
| `service-access-info.physical-person.firstname` | Determines which forge-text template is used |
| `service-access-info.physical-person.lastname` | Used in personalized forge-text template |

### Input Validation Notes

Custom ESQL explicitly validates only:

- `X-Caller-Code` header
- `service-access-info.contact-reason`

Other fields are required by Swagger, but additional custom validation is **not visible** in the provided ESQL. Some validation may be performed by the generated REST framework or by API gateway layers, but that is **not visible in provided source**.

---

## High-Level Architecture / Runtime Flow

```text
HTTP Input
  |
  v
Route To Label
  |
  +--> health
  |      |
  |      v
  |    health.subflow
  |      |
  |      v
  |    HTTP Reply
  |
  +--> postSmsOnlineAssistanceRequest
         |
         v
       log-entry
         |
         v
       TryCatch
         |
         +--> try
         |     |
         |     v
         |   FlowOrder FO1
         |     |
         |     +--> checkCallerCode
         |     |
         |     +--> FlowOrder FO2
         |            |
         |            +--> getUserPolicyValues
         |            |
         |            +--> FlowOrder FO3
         |                   |
         |                   +--> setEnv
         |                   |     |
         |                   |     v
         |                   |   callJwtGenService
         |                   |     |
         |                   |     v
         |                   |   callUrlShortenerService
         |                   |     |
         |                   |     +--> success short URL
         |                   |     |
         |                   |     +--> error/failure fallback URL
         |                   |             |
         |                   |             v
         |                   |          callForgeTextService
         |                   |             |
         |                   |             v
         |                   |          callSendSmsService
         |                   |
         |                   +--> setResponse
         |
         +--> catch
               |
               v
             build_http_error
               |
               v
             HTTP Reply
```

### Runtime Overview

The service is a REST-generated ACE application. The generated entry flow receives HTTPS requests and routes them by REST operation name to either the health subflow or the main POST subflow.

The POST implementation is structured as a controlled orchestration:

1. **Request logging and context capture** happen immediately.
2. A **TryCatch** protects the business flow.
3. **FlowOrder** nodes are used to sequence validation, policy loading, service orchestration, and final client response construction.
4. The main business chain makes four downstream HTTP calls:
   - JWT generation
   - URL shortening
   - forge-text generation
   - SMS sending
5. Any fatal exception is caught and converted into a standard JSON error by `build_http_error.subflow`.

A key design choice is that the **URL shortener is optional** from a business continuity perspective: visible code shows that URL shortener success and URL shortener failure both continue to forge-text generation. This means the flow can still send an SMS even if URL shortening fails.

Another important design choice is that the client response is **not built from the SMS provider response**. The service returns a synthesized business acknowledgment in `postSmsOnlineAssistanceRequest_setResponse`.

---

## Operation-by-Operation Documentation

## `GET /health`

**Purpose**

Returns a simple health payload for service liveness.

**Flow**

```text
HTTP Input -> Route To Label -> health.subflow -> HTTP Reply
```

**Main behavior**

- Builds a JSON object with:
  - `status = "pass"`
  - `api = ApplicationLabel`
  - current timestamp in ISO-like character format
- No external calls
- No custom error handling is visible in this subflow

**Pseudo-code**

```pseudo
on GET /health:
    output.status = "pass"
    output.api = ApplicationLabel
    output.timestamp = current timestamp
    return 200
```

---

## `POST /sms-online-assistance-request`

**Purpose**

Generates an online assistance access link, turns it into SMS text, sends the SMS, and returns an acknowledgment payload.

**Flow**

```text
Input
 -> log-entry
 -> TryCatch
    -> validate caller code and contact reason
    -> load policies for requested contact reason
    -> extract request fields into Environment
    -> call JWT service
    -> call URL shortener service
    -> call forge-text service
    -> call SMS service
    -> build acknowledgment response
 catch
    -> build standardized HTTP error JSON
```

**Main behavior**

- Logs inbound context and emits a monitoring event for request reception.
- Requires inbound `X-Caller-Code`.
- Requires `service-access-info.contact-reason`.
- Loads brand-specific and global policy configuration.
- Chooses one of two forge-text templates:
  - personalized template if `firstname` is present
  - generic template otherwise
- Retrieves an access token from a JWT service.
- Builds a redirect URL from configured policy values and the JWT access token.
- Attempts to shorten the URL, but continues even if shortening fails.
- Calls forge-text API to create SMS content using functional context, language, and template items.
- Calls SMS API with the final message text and sender code.
- Returns a response body largely based on the original request, augmented with:
  - current timestamp
  - empty `content`
  - selected `template-id`
  - `source-name` set from inbound `X-Caller-Code`
  - `channel-association = "HTTP"`

**Inferred downstream response dependencies**

These fields are not defined by schemas in the provided source, but are clearly required by downstream steps:

| Downstream call | Field expected from response | Why |
|---|---|---|
| JWT service | `access_token` | Used to build redirect URL |
| URL shortener | `url.keyword` | Used to construct final short URL |
| forge-text | `content` | Used as SMS message text |
| SMS service | none visible | Response body is not used by parent flow |

**Pseudo-code**

```pseudo
on POST /sms-online-assistance-request:
    log request and save headers/context

    if X-Caller-Code missing:
        fail with 400 ACEFONC0001

    if contact-reason missing:
        fail with 400 ACEFONC0001

    load global hosts, credentials, endpoints, and contact-reason policy values
    extract language, phone numbers, first/last name, sender code

    if firstname exists:
        template-id = 1
        functionalContext = personalized forge-text template
    else:
        template-id = 2
        functionalContext = generic forge-text template

    call JWT API using contacted phone number
    get access_token

    build long redirect URL from configured template + access_token
    call URL shortener
    if shortener succeeds:
        url-client = short-url-in-sms + "/" + keyword
    else:
        keep previously built long redirect URL

    call forge-text API with:
        functionalContext
        language
        template items:
            - short-link
            - optionally first_name and last_name

    if forge-text response has no content:
        fail with 502 ACETECH0004

    call SMS API with:
        phone-number = number-contacted
        message-text = forge-text content
        sender-code = contact-reason

    build business acknowledgment response from original request
    return success
```

---

## Core Components / Subflows

## `postSmsOnlineAssistanceRequest.subflow`

File:

```text
postSmsOnlineAssistanceRequest.subflow
```

**Purpose**

Main orchestration for the SMS online assistance request.

**Node-level flow**

```text
Input
 -> log-entry
 -> TryCatch
    -> try:
         FO1
           first  -> checkCallerCode
           second -> FO2
                       first  -> getUserPolicyValues
                       second -> FO3
                                   first  -> setEnv -> callJwtGenService -> callUrlShortenerService -> callForgeTextService -> callSendSmsService
                                   second -> setResponse
    -> catch:
         build_http_error
 -> Output
```

**Detailed behavior**

- `log-entry`
  - Copies input to output.
  - Stores request, correlation data, and TCS/SUP log context into `Environment`.
  - Saves inbound headers such as `X-Caller-Code` and `X-Global-Transaction-Id`.
  - Uses `PROPAGATE TO TERMINAL 1 DELETE NONE` to emit an extra copy to a dead-end `Pass through` branch. This appears to exist mainly to trigger the monitor event `"SUP: RECEIVE request from IVR"` without affecting main processing.

- `Try Catch`
  - Encapsulates the orchestration.
  - Any thrown user exception is routed to `build_http_error`.

- `FO1`
  - First branch validates mandatory caller metadata.
  - Second branch continues the flow only after validation branch execution.

- `FO2`
  - First branch loads policies and credentials.
  - Second branch continues into runtime business processing.

- `FO3`
  - First branch performs the downstream service orchestration.
  - Second branch builds the final business response using values accumulated in `Environment`.

**Important runtime data**

| Variable / Tree | Usage |
|---|---|
| `Environment.Variables."X-Caller-Code"` | Inbound caller code; later echoed in response |
| `Environment.Variables."X-Global-Transaction-Id"` | Correlation ID propagated downstream and returned in errors |
| `Environment.Variables.XCorrelationID` | Secondary correlation header for downstream calls |
| `Environment.Variables.policy.*` | Loaded endpoint, credential, and template configuration |
| `Environment.Variables.FunctionalContext` | Forge-text functional context / template key |
| `Environment.Variables."template-id"` | Response template ID, `1` or `2` |
| `Environment.Variables."url-client"` | Long or short URL used in SMS text generation |
| `Environment.Variables.TCSLog.*` | Logging/monitoring context |
| `Environment.Request` | Copy of inbound request; not otherwise used in visible source |

---

## `callJwtGenService.subflow`

File:

```text
callJwtGenService.subflow
```

**Purpose**

Calls the JWT generation API and returns its response to the parent flow.

**Node-level flow**

```text
Input
 -> set_jwt_gen_parameters
 -> WSRequest common-api-technical-security-jwt-internal
    +--> out     -> HandleResponse -> Output
    +--> error   -> HandleHttpError -> buildError -> exception
    +--> failure -> HandleHttpFailure -> buildError -> exception
```

**Detailed behavior**

- Prepares outbound headers:
  - `x-ibm-client-id`
  - `X-Global-Transaction-Id`
  - `aud-claim`
  - `X-Caller-Code = ApplicationLabel`
  - `X-Origin-Caller-Code`
  - `X-Correlation-ID`
- Builds request URL as:
  - `JwtTokenServicePoliciesEndPoint || '/gen'`
- Builds request JSON body with:
  - `phoneNumber = service-access-info.number-contacted`
- Normalizes only the JWT request phone number:
  - if it starts with `00`, it is converted to `+...`
- On success, passes provider response through unchanged via `PrepareHTTPResponse`.
- On HTTP error or failure, converts downstream/provider problems into a thrown user exception.

**HTTP error mapping**

Fatal JWT errors use `callJwtGenService_buildError`:

- If the original HTTP code is in `400,401,403,404,429,501,502,503`, that code is reused.
- Otherwise ACE returns `502`.
- Error provider is set to `APIC`.
- Error reference is `ACETECH0004`.

---

## `callUrlShortenerService.subflow`

File:

```text
callUrlShortenerService.subflow
```

**Purpose**

Attempts to shorten the redirect URL. This step is visibly non-fatal.

**Node-level flow**

```text
Input
 -> set-url-shortener-parameters
 -> WSRequest support-it-api-url-shortener
    +--> out     -> HandleResponse -> getShortUrl -> Output
    +--> error   -> HandleHttpError -> Output
    +--> failure -> HandleHttpFailure -> Error
```

**Detailed behavior**

- Builds outbound APIC credentials and correlation headers.
- Replaces `${language}` placeholders in policy-based redirect URLs.
- Builds a long redirect URL using:
  - configured webapp redirect base
  - JWT `access_token`
- Builds the URL shortener endpoint using:
  - URL shortener base endpoint
  - configured query string template
  - URL-encoded success and error redirect URLs
  - signature from policy
- On success:
  - `getShortUrl` sets `Environment.Variables."url-client"` to a final SMS URL derived as:
    - `policy."short-url-in-sms" + '/' + InputRoot.JSON.Data.url.keyword`
  - Although `InputRoot.JSON.Data.shorturl` is first copied into `url-client`, it is immediately overwritten. The actual final SMS link therefore comes from the policy prefix plus the returned keyword.
- On HTTP error/failure:
  - the subflow does **not** throw an exception
  - it only records error details and returns
  - the parent flow still continues to forge-text generation

**Important behavior**

This is a deliberate resilience point:

- **Visible fact**: URL shortener failure does not stop the main orchestration.
- **Visible implication**: the previously built long redirect URL remains in `Environment.Variables."url-client"` and can still be used in the SMS text.

---

## `callForgeTextService.subflow`

File:

```text
callForgeTextService.subflow
```

**Purpose**

Calls the forge-text API to create the final SMS content from templates and configuration items.

**Node-level flow**

```text
Input
 -> set-forge-text-parameters
 -> WSRequest support-content-mgt-api-forge-text
    +--> out     -> HandleResponse -> Output
    +--> error   -> HandleHttpError -> buildError -> exception
    +--> failure -> HandleHttpFailure -> buildError -> exception
```

**Detailed behavior**

- Sets APIC headers using `ace_app_esb.client_id` and `client_secret`.
- Sets Basic Authorization for forge-text credentials from policy.
- Propagates `X-Global-Transaction-Id`.
- Sets `Content-Type = application/json; charset=utf-8`.
- Sets `X-Caller-Code = ApplicationLabel`.
- Builds request body:
  - `functionalContext`
  - `language` in lowercase
  - `configurationItems[]`

Configuration item logic:

- If using the personalized template:
  - `first_name`
  - `last_name`
  - `short-link`
- If using the generic template:
  - `short-link` only

Names are normalized using `translateSpecialCharForNames(...)` before being sent.

On HTTP error/failure:

- provider name is set to `FORGETEXT`
- error reference is `ACETECH0004`
- HTTP status is either preserved from approved provider codes or mapped to `502`
- the module throws a user exception including template context information

---

## `callSendSmsService.subflow`

File:

```text
callSendSmsService.subflow
```

**Purpose**

Calls the SMS service to send the generated message text.

**Node-level flow**

```text
Input
 -> set-send-sms-parameters
 -> WSRequest support-it-api-sms
    +--> out     -> HandleResponse -> Pass through
    +--> error   -> HandleHttpError -> buildError -> exception
    +--> failure -> HandleHttpFailure -> buildError -> exception
```

**Detailed behavior**

- Before calling the SMS provider, it checks that forge-text actually returned `InputRoot.JSON.Data.content`.
- If `content` is empty:
  - sets `HttpReturnCode = 502`
  - sets `ErrorRefApp = ACETECH0004`
  - throws `No content returned by the forge-text service !`
  - no SMS call is attempted
- Builds outbound request body:
  - `phone-number = Environment.Variables."number-contacted"`
  - `message-text = InputRoot.JSON.Data.content`
  - `sender-code = Environment.Variables."sender-code"`
- Propagates:
  - `X-Global-Transaction-Id`
  - `X-Caller-Code = ApplicationLabel`
  - `X-Origin-Caller-Code`
  - `X-Correlation-ID`
- On success, the downstream SMS response is not used by the parent flow.
- The subflow has no exposed success output terminal back to the caller flow; success is effectively side-effect only.

**Fatal error mapping**

- provider name: `NETOXYGEN`
- reference: `ACETECH0004`
- provider codes in the approved list are preserved; others are mapped to `502`

---

## `build_http_error.subflow`

File:

```text
build_http_error.subflow
```

**Purpose**

Builds the final standardized JSON HTTP error returned to the client.

**Node-level flow**

```text
Input -> create_body -> Output
```

**Detailed behavior**

`build_http_error_create_body` does the following:

1. Copies message headers from input to output.
2. If an `InputExceptionList` exists and `Environment.Variables.ExceptionStackTrace` is still empty:
   - parses exception number/message/stacktrace using `parseExceptionList(...)`
   - also serializes the full exception tree into JSON text and stores it in `Environment.Variables.ExceptionStackTrace`
3. Defaults provider name to `ACE` if not already set.
4. Defaults HTTP status to `500` and `ErrorRefApp = ACETECH0001` if not already set.
5. Sets:
   - `OutputLocalEnvironment.Destination.HTTP.ReplyStatusCode`
   - `OutputRoot.JSON.Data.timestamp`
   - `OutputRoot.JSON.Data.httpCode`
   - `OutputRoot.JSON.Data.httpMessage`
   - `OutputRoot.JSON.Data.refAppError`
   - `OutputRoot.JSON.Data.gtid`
   - `OutputRoot.JSON.Data.moreInformation`
6. Updates TCS/SUP log error fields from the final response.

**Resulting error payload shape**

```json
{
  "timestamp": "2026-06-26T10:11:12.123456",
  "httpCode": "FORGETEXT : 502",
  "httpMessage": "FORGETEXT : The API call to forge the final text from the template [1:...] failed !",
  "refAppError": "ACETECH0004",
  "gtid": "....",
  "moreInformation": "...."
}
```

---

## Key ESQL / Logic Analysis

## `postSmsOnlineAssistanceRequest_logEntry`

File:

```text
postSmsOnlineAssistanceRequest_logEntry.esql
```

**Purpose**

Initializes runtime context, logging metadata, and correlation data.

**What it does**

- Copies the full input message to output.
- Stores a business identifier:
  - phone number from `service-access-info.number-contacted`
- Saves inbound headers into `Environment.Variables`
  - `X-Caller-Code`
  - `X-Global-Transaction-Id`
- Saves the entire request in `Environment.Request`.
- Generates a `trackID` with `UUIDASCHAR`.
- Sets `XCorrelationID` from global transaction ID.
- Captures inbound URI from `InputLocalEnvironment.REST.Input.URI`.
- Initializes `TCSLog.context` fields such as severity, origin-caller, caller-code, target-url, source-system, and target-system.
- Emits an additional propagated copy to terminal 1, apparently to support the request-received monitor event.

**Pseudo-code**

```pseudo
copy input to output

Environment.TCSLog.business-identifiers.phone-number = request.number-contacted
Environment.X-Caller-Code = header.X-Caller-Code
Environment.X-Global-Transaction-Id = header.X-Global-Transaction-Id
Environment.Request = full input request
Environment.trackID = UUID
Environment.XCorrelationID = X-Global-Transaction-Id
Environment.In.targeturl = REST URI
Environment.In.XCallerCode = header.X-Caller-Code

Environment.TCSLog.context.severity = "INFO"
Environment.TCSLog.context.origin-caller = header.X-Origin-Caller-Code or header.X-Caller-Code
Environment.TCSLog.context.caller-code = header.X-Caller-Code
Environment.TCSLog.context.target-url = REST URI
Environment.TCSLog.context.source-system = "CMP05737"
Environment.TCSLog.context.target-system = "CMP05541"

PROPAGATE copy to out1 for monitoring
return true
```

---

## `postSmsOnlineAssistanceRequest_getUserPolicyValues`

File:

```text
postSmsOnlineAssistanceRequest_getUserPolicyValues.esql
```

**Purpose**

Loads all policy-driven configuration required by the orchestration.

**What it does**

- Reads global host values:
  - `apic-host`
  - `apic-host-old`
  - `ace-host`
- Loads all properties for a policy whose name is derived from:
  - `UPPER(InputRoot.JSON.Data."service-access-info"."contact-reason")`
- Stores loaded policy tree in:
  - `Environment.Variables.policy.exchange-integration-policies-properties-digitalintake`
- Reads and builds:
  - client IDs / secret
  - JWT endpoint
  - JWT audience claim
  - URL shortener parameters
  - redirect URLs
  - public short URL prefix
  - forge-text template identifiers
  - SMS endpoint
  - URL shortener endpoint and signature
  - forge-text endpoint and credentials

**Important design**

Policy retrieval failures are explicitly turned into business errors:

- missing policy deployment -> `422`, `ACETECH0002`
- missing property -> `422`, `ACEFONC0012`

These are visible runtime behaviors, and `422` is a real possible response even though it is not declared in the active Swagger.

**Pseudo-code**

```pseudo
copy input to output

hostApicNewTopo = policy(GlobalEndpointsPolicy.apic-host)
hostApicOldTopo = policy(GlobalEndpointsPolicy.apic-host-old)
hostAce         = policy(GlobalEndpointsPolicy.ace-host)

load all properties for policy named UPPER(contact-reason)
into Environment.Variables.policy.exchange-integration-policies-properties-digitalintake

Environment.policy.ACE_ClientID = policy(AceAppEsbCredentialsPolicy.client_id_old_topo)
Environment.ace_app_esb.client_id = policy(AceAppEsbCredentialsPolicy.client_id)
Environment.ace_app_esb.client_secret = policy(AceAppEsbCredentialsPolicy.client_secret)

Environment.policy.JwtTokenServicePoliciesEndPoint = hostApicOldTopo + path-common-api-technical-security-jwt-internal
Environment.policy.claimsDigitalIntake = loaded property claims-digital-intake

Environment.policy.UrlShortenerEndPointParameters = loaded property url-shortener-parameters
Environment.policy.UrlRedirectWebApp = loaded property url-redirect-webapp
Environment.policy.UrlRedirectError = loaded property url-redirect-webapp-error
Environment.policy.short-url-in-sms = loaded property short-url-in-sms

Environment.policy.forgetext_link_request_template = loaded property forgetext-link-request-templates
Environment.policy.forgetext_link_request_without_person_template = loaded property forgetext-link-request-without-person-templates

Environment.policy.sendSmsApiEndPoint = hostAce + path-support-it-integration-sms
Environment.policy.urlshortener.urlshortener-endpoint-url = hostApicNewTopo + path-support-it-api-url-shortener
Environment.policy.urlshortener.signature = policy(UrlshortenerCredentials.signature)

Environment.policy.forgetext.forge-text-endpoint-url = hostApicNewTopo + path-support-content-mgt-api-forge-text
Environment.policy.forgetext.user = policy(ForgeTextCredentials.User-api)
Environment.policy.forgetext.password = policy(ForgeTextCredentials.Password-api)
```

---

## `postSmsOnlineAssistanceRequest_setEnv`

File:

```text
postSmsOnlineAssistanceRequest_setEnv.esql
```

**Purpose**

Extracts request data into `Environment.Variables` and selects the forge-text template strategy.

**What it does**

- Copies input to output.
- Stores:
  - `language`
  - `number-initiating`
  - `number-contacted`
  - `lastname`
  - `firstname`
- Selects template logic:
  - if `firstname` length > 0:
    - `template-id = 1`
    - `FunctionalContext = personalized template`
  - else:
    - `template-id = 2`
    - `FunctionalContext = generic template`
- Sets SMS `sender-code` from `contact-reason`

**Notes**

- The code comment explicitly says `number-initiating` does not seem to be used today.
- Template selection depends only on `firstname`, not on `lastname`.

---

## `callUrlShortenerService_set_url_shortener_parameters`

File:

```text
callUrlShortenerService_set_url_shortener_parameters.esql
```

**Purpose**

Builds the redirect URL and the URL shortener request URL.

**What it does**

- Sets APIC credentials and tracing headers.
- Replaces `${language}` placeholders in policy URLs.
- Builds initial long client URL:
  - `UrlRedirectWebApp + access_token`
- Replaces placeholders inside URL shortener query parameter template:
  - `${url-redirect-webapp-error}`
  - `${url-redirect-webapp}`
- URL-encodes redirect URLs.
- Builds final request URL including `signature`.

**Important behavior**

If the shortener call later fails, this already-computed long URL remains available in `Environment.Variables."url-client"` and is the natural fallback used by later steps.

---

## `callForgeTextService_set_forge_text_parameters`

File:

```text
callForgeTextService_set_forge_text_parameters.esql
```

**Purpose**

Builds the forge-text request payload.

**What it does**

- Copies `InputRoot.Properties`.
- Sets APIC and Basic Auth headers.
- Builds JSON payload with:
  - `functionalContext`
  - `language`
  - `configurationItems[]`
- For personalized template, adds normalized `first_name` and `last_name`.
- Always adds the URL under key `short-link`.

**Relevant helper logic**

`translateSpecialCharForNames(...)` in `globalFunctions.esql` removes/normalizes accented letters and punctuation before sending names to forge-text.

---

## `globalFunctions.esql`

File:

```text
globalFunctions.esql
```

**Purpose**

Provides cross-flow helper functions.

**Most important visible functions**

| Function / Procedure | Purpose |
|---|---|
| `parseExceptionList(...)` | Extracts exception number, message, and stack trace |
| `translateSpecialCharForNames(...)` | Normalizes names sent to forge-text |
| `getSinglePropertyFromPolicyProject(...)` | Reads one policy property and throws `422` on missing policy/property |
| `getAllPropertiesFromPolicyProject(...)` | Loads all properties of a policy into a specified `Environment` tree |
| `getPropertyFromAllPolicies(...)` | Reads a property from the previously loaded tree and throws `422` if missing |

**Fact vs inference**

- The control flow around these helpers is fully visible.
- The actual backing policy retrieval implementation is not visible because it comes from `SHLIB_PoliciesReader`.

---

## Branching / Propagation / Batch Processing

### Branching behavior

The service uses several branching constructs intentionally:

#### 1. `TryCatch`
Used in `postSmsOnlineAssistanceRequest.subflow` to ensure thrown user exceptions are converted into a standard HTTP error payload.

#### 2. `FlowOrder`
Used three times to impose ordered side branches:

- `FO1`
  - branch 1: validate caller/request
  - branch 2: continue only after validation step

- `FO2`
  - branch 1: load policies
  - branch 2: continue only after configuration step

- `FO3`
  - branch 1: perform external orchestration
  - branch 2: build final response

This pattern makes the main response construction independent of downstream provider response bodies.

#### 3. URL shortener dual-output continuation
`callUrlShortenerService` exposes both success and error-style outputs, but the parent flow connects both to `callForgeTextService`. Visible effect:

- shortener success -> use short URL
- shortener failure/error -> continue with fallback URL

### Propagation behavior

`postSmsOnlineAssistanceRequest_logEntry` explicitly uses:

```pseudo
PROPAGATE TO TERMINAL 1 DELETE NONE;
```

Visible purpose:

- emit a duplicate copy of the inbound request on a secondary branch
- preserve the main message flow
- likely support monitoring event emission without impacting business logic

No other multi-message or batching propagation is visible.

### Batch handling

No batch processing is present in the provided source.

---

## Error Handling and Monitoring

## Error Handling

### Fatal errors returned to the client

The following visible situations are fatal and end in `build_http_error`:

| Scenario | HTTP code | Ref code | Provider name in response |
|---|---:|---|---|
| Missing `X-Caller-Code` | `400` | `ACEFONC0001` | defaults to `ACE` |
| Missing `contact-reason` | `400` | `ACEFONC0001` | defaults to `ACE` |
| Missing policy deployment | `422` | `ACETECH0002` | `ACE` |
| Missing policy property | `422` | `ACEFONC0012` | `ACE` |
| JWT API error/failure | provider code or `502` | `ACETECH0004` | `APIC` |
| Forge-text API error/failure | provider code or `502` | `ACETECH0004` | `FORGETEXT` |
| SMS API error/failure | provider code or `502` | `ACETECH0004` | `NETOXYGEN` |
| Forge-text returned no `content` | `502` | `ACETECH0004` | defaults to `ACE` unless set elsewhere |
| Unclassified internal error | `500` | `ACETECH0001` | `ACE` |

### Non-fatal errors

Visible non-fatal case:

- URL shortener HTTP error/failure  
  The flow logs the issue and continues. This is a deliberate fallback design.

### Error payload format

Errors are normalized to:

```json
{
  "timestamp": "2026-06-26T10:11:12.123456",
  "httpCode": "ACE : 400",
  "httpMessage": "ACE : The caller code header is required to continue the treatment !",
  "refAppError": "ACEFONC0001",
  "gtid": "....",
  "moreInformation": "...."
}
```

### Important discrepancy with Swagger

`swagger.json` declares `400/401/403/404/429/500/501/502/503`, but the provided ESQL can also explicitly return:

```text
422
```

for configuration/policy-related failures.

## Monitoring

The flow is instrumented with multiple monitor events. Key visible events include:

| Node / Component | Event | Notes |
|---|---|---|
| `postSmsOnlineAssistanceRequest_logEntry` | `SUP: RECEIVE request from IVR` | Request ingress |
| JWT request node | `INFO/END/FAIL/ERROR` events | Outbound JWT API call lifecycle |
| JWT response handler | `SUP: RECEIVE response from common-api-technical-security-jwt-internal` | Successful JWT response |
| URL shortener request node | `INFO/END/FAIL/ERROR` events | Outbound shortener call lifecycle |
| forge-text request node | `INFO/END/FAIL/ERROR` events | Outbound forge-text call lifecycle |
| SMS request node | `INFO/END/FAIL/ERROR` events | Outbound SMS call lifecycle |
| `build_http_error.create_body` | `SUP: SEND Error response to IVR` | Final client error response |

The monitoring model consistently captures:

- request send
- request end
- HTTP error terminal
- HTTP failure terminal
- received downstream response
- emitted error response

---

## Configuration, Policies, and External Dependencies

## Policies / Config

### Global host and endpoint configuration

| Policy / Property | Used By | Purpose |
|---|---|---|
| `{GlobalEndpointsPolicies}:GlobalEndpointsPolicy / apic-host` | `getUserPolicyValues` | New APIC host |
| `{GlobalEndpointsPolicies}:GlobalEndpointsPolicy / apic-host-old` | `getUserPolicyValues` | Old APIC host |
| `{GlobalEndpointsPolicies}:GlobalEndpointsPolicy / ace-host` | `getUserPolicyValues` | ACE host |

### Credentials and technical security

| Policy / Property | Used By | Purpose |
|---|---|---|
| `{AceAppEsbCredentialsPolicies}:AceAppEsbCredentialsPolicy / client_id_old_topo` | JWT call | APIC client ID for JWT generation |
| `{AceAppEsbCredentialsPolicies}:AceAppEsbCredentialsPolicy / client_id` | URL shortener / forge-text | APIC client ID |
| `{AceAppEsbCredentialsPolicies}:AceAppEsbCredentialsPolicy / client_secret` | URL shortener / forge-text | APIC client secret |
| `{exchange-integration-policies-credentials}:UrlshortenerCredentials / signature` | URL shortener | Request signing |
| `{exchange-integration-policies-credentials}:ForgeTextCredentials / User-api` | forge-text | Basic auth username |
| `{exchange-integration-policies-credentials}:ForgeTextCredentials / Password-api` | forge-text | Basic auth password |

### Per-contact-reason digital intake properties

Loaded from policy project:

```text
exchange-integration-policies-properties-digitalintake
```

using policy name:

```text
UPPER(service-access-info.contact-reason)
```

Visible properties consumed:

| Property | Purpose |
|---|---|
| `claims-digital-intake` | JWT audience claim |
| `url-shortener-parameters` | Shortener query string template |
| `url-redirect-webapp` | Success redirect base URL |
| `url-redirect-webapp-error` | Error redirect base URL |
| `short-url-in-sms` | Public URL prefix used in final SMS |
| `forgetext-link-request-templates` | Personalized forge-text context |
| `forgetext-link-request-without-person-templates` | Generic forge-text context |

### Endpoint paths

| Policy / Property | Purpose |
|---|---|
| `{exchange-integration-policies-endpoints}:ApicEndPoints / path-common-api-technical-security-jwt-internal` | JWT endpoint path |
| `{exchange-integration-policies-endpoints}:ApicEndPoints / path-support-it-api-url-shortener` | URL shortener path |
| `{exchange-integration-policies-endpoints}:ApicEndPoints / path-support-content-mgt-api-forge-text` | forge-text path |
| `{exchange-integration-policies-endpoints}:AceEndPoints / path-support-it-integration-sms` | SMS endpoint path |

## Shared Libraries / External Components

| Component | Source | Visible Usage | Notes |
|---|---|---|---|
| `Shlib_PoliciesReader.getPolicyPropertyWithOutError` | `SHLIB_PoliciesReader` | Reads one policy property | Internal logic not visible |
| `Shlib_PoliciesReader.getAllPolicyProperties` | `SHLIB_PoliciesReader` | Loads all properties of a policy into an Environment tree | Internal logic not visible |
| JWT API | external HTTP service | Generates access token | Response schema not visible; `access_token` inferred |
| URL shortener API | external HTTP service | Shortens generated redirect URL | `url.keyword` inferred from code |
| forge-text API | external HTTP service | Generates final SMS text from templates | `content` inferred from code |
| SMS API | external HTTP service | Sends SMS | Success payload not used in visible code |

---

## Outputs / Responses

## Success Response

Status / output:

```text
Default HTTP success status appears to be 200.
```

Visible success body built by ACE:

```json
{
  "service-access-info": {
    "number-initiating": "...",
    "number-contacted": "...",
    "create-date-time": "2026-06-26T10:11:12.123456",
    "content": "",
    "language": "fr",
    "contact-type": "outbound",
    "contact-reason": "ONLINEASSY",
    "physical-person": {
      "firstname": "John",
      "lastname": "Doe"
    },
    "template": {
      "template-id": 1
    },
    "source": {
      "source-name": "GenesysOrCallerCode",
      "channel-association": "HTTP"
    }
  },
  "request-type": "OA_LINK_REQUEST"
}
```

### Success response notes

- The response is synthesized by `postSmsOnlineAssistanceRequest_setResponse`.
- It is largely based on the original request body.
- It does **not** include the SMS provider response.
- `content` is explicitly blanked out.
- `template-id` is derived from whether `firstname` was present.
- `source.source-name` is set from inbound `X-Caller-Code`.
- `source.channel-association` is set to `"HTTP"`.

There is a visible mismatch risk between this response and the Swagger schema, especially around `source` semantics.

## Error Response

Status / output:

```text
HTTP status is explicitly set from Environment.Variables.HttpReturnCode, defaulting to 500.
```

Example shape:

```json
{
  "timestamp": "2026-06-26T10:11:12.123456",
  "httpCode": "APIC : 502",
  "httpMessage": "APIC : The API call for generating the JWT token from APIC failed !",
  "refAppError": "ACETECH0004",
  "gtid": "abc-123",
  "moreInformation": "serialized exception details"
}
```

### Error response notes

- `httpCode` and `httpMessage` are prefixed with the visible provider name.
- `moreInformation` may contain serialized exception details.
- `gtid` is copied from `X-Global-Transaction-Id`.

---

## End-to-End Pseudo-code

```pseudo
on incoming HTTPS REST request:
    route by REST operation

    if operation == health:
        return {
            status: "pass",
            api: ApplicationLabel,
            timestamp: now()
        }

    if operation == postSmsOnlineAssistanceRequest:
        try:
            copy request to output/environment
            capture X-Caller-Code, X-Global-Transaction-Id, origin caller
            initialize logging and monitoring context

            if X-Caller-Code is empty:
                set 400 / ACEFONC0001
                throw

            if service-access-info.contact-reason is empty:
                set 400 / ACEFONC0001
                throw

            load policy set for UPPER(contact-reason)
            load hosts, endpoints, credentials, claims, redirect URL templates,
            short-url prefix, forge-text template names, SMS endpoint

            set environment values from request:
                language
                number-contacted
                firstname
                lastname
                sender-code = contact-reason

            if firstname exists:
                template-id = 1
                functionalContext = personalized template
            else:
                template-id = 2
                functionalContext = generic template

            call JWT service with phone number
            expect access_token

            build long redirect URL from policy + access_token
            call URL shortener

            if shortener succeeded:
                url-client = short-url-in-sms + "/" + keyword
            else:
                keep long redirect URL and continue

            call forge-text with:
                functionalContext
                language
                short-link = url-client
                optionally first_name and last_name

            if forge-text content missing:
                set 502 / ACETECH0004
                throw

            call SMS service with:
                phone-number = number-contacted
                message-text = forge-text content
                sender-code = contact-reason

            build synthetic success response from original request:
                create-date-time = now
                content = ""
                template-id = selected value
                source-name = inbound X-Caller-Code
                channel-association = "HTTP"

            return success

        catch any exception:
            if provider/status/refApp not already set:
                default to ACE / 500 / ACETECH0001

            parse or serialize exception details
            build JSON error with:
                timestamp
                provider-prefixed httpCode
                provider-prefixed httpMessage
                refAppError
                gtid
                moreInformation

            return error
```

--- 

## Additional Implementation Notes

- Inbound authentication/authorization logic is **not visible in the provided source**. It is likely handled upstream or by deployment configuration.
- URL shortener failure tolerance is one of the most important runtime characteristics of this service.
- The policy model is central: the request `contact-reason` determines templates, redirect behavior, sender branding, and JWT claims.
- A visible design intent is to provide stable client-facing acknowledgments while hiding downstream provider-specific payloads behind a standardized orchestration and error contract.