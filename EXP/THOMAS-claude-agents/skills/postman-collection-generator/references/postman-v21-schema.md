# Postman Collection v2.1 JSON Schema Reference

This file documents the exact structure required for a valid Postman Collection v2.1 JSON file,
with annotated examples relevant to IBM API non-regression testing.

---

## Top-level structure

```json
{
  "info": {
    "name": "My API - Non-Regression Tests",
    "description": "Generated collection for migration non-regression testing. Configure {{baseUrl}}, {{ibmClientId}}, {{ibmClientSecret}} in a Postman Environment before running.",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    { "key": "baseUrl", "value": "https://your-apic-gateway/api/v1", "type": "string" },
    { "key": "ibmClientId", "value": "FILL_ME", "type": "string" },
    { "key": "ibmClientSecret", "value": "FILL_ME", "type": "string" },
    { "key": "bearerToken", "value": "FILL_ME", "type": "string" }
  ],
  "item": [ /* folders and requests — see below */ ]
}
```

---

## Folder (ItemGroup)

```json
{
  "name": "Orders",
  "description": "Endpoints for order management",
  "item": [ /* requests */ ]
}
```

Folders can be nested (folder inside folder) for deeper grouping.

---

## Request item

```json
{
  "name": "POST /orders - Happy Path",
  "request": {
    "method": "POST",
    "header": [
      { "key": "Content-Type", "value": "application/json" },
      { "key": "Accept", "value": "application/json" },
      { "key": "X-IBM-Client-Id", "value": "{{ibmClientId}}" },
      { "key": "X-IBM-Client-Secret", "value": "{{ibmClientSecret}}" },
      { "key": "X-Correlation-Id", "value": "{{$guid}}" }
    ],
    "url": {
      "raw": "{{baseUrl}}/orders",
      "host": ["{{baseUrl}}"],
      "path": ["orders"]
    },
    "body": {
      "mode": "raw",
      "raw": "{\n  \"customerId\": \"CUST-001\",\n  \"items\": [{\"sku\": \"SKU-123\", \"qty\": 2}]\n}",
      "options": {
        "raw": { "language": "json" }
      }
    },
    "description": "Creates a new order. Source: Kibana trace 2024-01-15T10:23:44Z"
  },
  "event": [
    {
      "listen": "test",
      "script": {
        "type": "text/javascript",
        "exec": [
          "pm.test(\"Status code is 201\", function () {",
          "    pm.response.to.have.status(201);",
          "});",
          "",
          "pm.test(\"Response time is acceptable\", function () {",
          "    pm.expect(pm.response.responseTime).to.be.below(5000);",
          "});",
          "",
          "pm.test(\"Response contains orderId\", function () {",
          "    const jsonData = pm.response.json();",
          "    pm.expect(jsonData).to.have.property(\"orderId\");",
          "    pm.expect(jsonData.status).to.eql(\"CONFIRMED\");",
          "});",
          "",
          "// Backwards compatibility: ensure all pre-migration fields are still present",
          "pm.test(\"Backwards compatible response structure\", function () {",
          "    const jsonData = pm.response.json();",
          "    [\"orderId\", \"status\", \"createdAt\"].forEach(function(field) {",
          "        pm.expect(jsonData).to.have.property(field);",
          "    });",
          "});"
        ]
      }
    }
  ]
}
```

---

## Request with path parameters

```json
{
  "name": "GET /orders/{orderId} - Happy Path",
  "request": {
    "method": "GET",
    "header": [
      { "key": "Accept", "value": "application/json" },
      { "key": "X-IBM-Client-Id", "value": "{{ibmClientId}}" },
      { "key": "X-Correlation-Id", "value": "{{$guid}}" }
    ],
    "url": {
      "raw": "{{baseUrl}}/orders/{{orderId}}",
      "host": ["{{baseUrl}}"],
      "path": ["orders", "{{orderId}}"],
      "variable": [
        { "key": "orderId", "value": "ORD-12345", "description": "Order ID from trace" }
      ]
    }
  }
}
```

---

## Request with query parameters

```json
{
  "url": {
    "raw": "{{baseUrl}}/orders?status=CONFIRMED&page=1&pageSize=10",
    "host": ["{{baseUrl}}"],
    "path": ["orders"],
    "query": [
      { "key": "status", "value": "CONFIRMED" },
      { "key": "page", "value": "1" },
      { "key": "pageSize", "value": "10" }
    ]
  }
}
```

---

## Schema validation test script

Use `tv4` (built into Postman sandbox) for JSON Schema validation:

```javascript
const schema = {
  "type": "object",
  "required": ["orderId", "status"],
  "properties": {
    "orderId": { "type": "string" },
    "status": { "type": "string", "enum": ["PENDING", "CONFIRMED", "CANCELLED"] },
    "createdAt": { "type": "string", "format": "date-time" }
  }
};

pm.test("Response matches schema", function () {
    const jsonData = pm.response.json();
    pm.expect(tv4.validate(jsonData, schema)).to.be.true;
});
```

---

## Error case request

```json
{
  "name": "POST /orders - Error: Missing required field (400)",
  "request": {
    "method": "POST",
    "header": [
      { "key": "Content-Type", "value": "application/json" },
      { "key": "X-IBM-Client-Id", "value": "{{ibmClientId}}" },
      { "key": "X-Correlation-Id", "value": "{{$guid}}" }
    ],
    "url": {
      "raw": "{{baseUrl}}/orders",
      "host": ["{{baseUrl}}"],
      "path": ["orders"]
    },
    "body": {
      "mode": "raw",
      "raw": "{\n  \"items\": []\n}",
      "options": { "raw": { "language": "json" } }
    }
  },
  "event": [
    {
      "listen": "test",
      "script": {
        "type": "text/javascript",
        "exec": [
          "pm.test(\"Status code is 400\", function () {",
          "    pm.response.to.have.status(400);",
          "});",
          "pm.test(\"Error response contains message\", function () {",
          "    const jsonData = pm.response.json();",
          "    pm.expect(jsonData).to.have.property(\"message\");",
          "});"
        ]
      }
    }
  ]
}
```

---

## Pre-request script (collection-level auth example)

Attach at collection or folder level under `event` with `"listen": "prerequest"`:

```json
{
  "listen": "prerequest",
  "script": {
    "type": "text/javascript",
    "exec": [
      "// Auto-refresh bearer token if needed",
      "// pm.environment.set('bearerToken', '<token logic here>');"
    ]
  }
}
```

---

## Complete minimal collection skeleton

```json
{
  "info": {
    "name": "API Name - Non-Regression Tests",
    "description": "...",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    { "key": "baseUrl", "value": "", "type": "string" },
    { "key": "ibmClientId", "value": "", "type": "string" }
  ],
  "item": [
    {
      "name": "Resource Group",
      "item": [
        {
          "name": "GET /resource - Happy Path",
          "request": { "method": "GET", "header": [], "url": { "raw": "{{baseUrl}}/resource", "host": ["{{baseUrl}}"], "path": ["resource"] } },
          "event": [{ "listen": "test", "script": { "type": "text/javascript", "exec": ["pm.test(\"Status 200\", () => pm.response.to.have.status(200));"] } }]
        }
      ]
    }
  ]
}
```

---

## Postman Environment file format (v2.1)

Generate one per environment: QA, ACP (Acceptance/Pre-Production), PROD.

```json
{
  "name": "<API Name> - QA",
  "_postman_variable_scope": "environment",
  "values": [
    {
      "key": "baseUrl",
      "value": "FILL_ME_QA_APIC_URL",
      "type": "default",
      "enabled": true,
      "description": "APIC gateway base URL for QA. Path structure from PROD Kibana: /api/v1/policies"
    },
    {
      "key": "ibmClientId",
      "value": "FILL_ME_QA_CLIENT_ID",
      "type": "default",
      "enabled": true,
      "description": "IBM APIC Client ID for QA environment"
    },
    {
      "key": "ibmClientSecret",
      "value": "FILL_ME_QA_CLIENT_SECRET",
      "type": "secret",
      "enabled": true,
      "description": "IBM APIC Client Secret for QA environment"
    },
    {
      "key": "language",
      "value": "fr",
      "type": "default",
      "enabled": true,
      "description": "Response language: fr, de, it, en"
    }
  ]
}
```

Notes:
- Use `"type": "secret"` for credentials so Postman masks them in the UI
- Add test-data variables here too if they differ per environment (e.g. `testContactId`, `testPolicyNumber`)
- The three environment files are identical in structure; only the `name` field and `value` fields differ
- Hostname differs per environment; path structure (e.g. `/api/v1/resource`) is typically the same across QA/ACP/PROD

---

## Key rules

- `url.raw` must always be set and match the constructed URL
- `url.host` should be `["{{baseUrl}}"]` — do NOT split the variable further
- `event` is an array — a single request can have both `prerequest` and `test` events
- Test scripts go in `exec` as an **array of strings**, one per line
- All dynamic values use Postman syntax: `{{variableName}}` or `{{$guid}}`, `{{$timestamp}}`
- Do not use `undefined` or `null` for string values — use `""` or a placeholder string
