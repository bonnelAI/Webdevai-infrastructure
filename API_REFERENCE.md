# Kestra Staging API Reference

REST API endpoints for managing Railway staging environments via Kestra webhooks.

## Base URL

```
https://your-kestra-domain.railway.app
```

## Authentication

All webhook endpoints require a webhook key in the URL path (no additional headers needed).

## Endpoints

### 1. Clone Staging Environment

Create a new staging environment by cloning from production.

**Endpoint:**
```
POST /api/v1/executions/webhook/dev.deployment/clone-staging-api/{WEBHOOK_KEY}
```

**Request Body:**
```json
{
  "client_name": "string (required)",
  "environment_name": "string (optional)",
  "source_environment": "string (default: production)",
  "skip_database": "boolean (default: false)"
}
```

**Parameters:**
- `client_name` - Client identifier for naming (e.g., "acme-corp")
- `environment_name` - Custom name (auto-generated if empty)
- `source_environment` - Environment to clone from
- `skip_database` - Skip database sync (environment only)

**Response:**
```json
{
  "executionId": "01HQRS...",
  "state": "CREATED"
}
```

**Example:**
```bash
curl -X POST "https://kestra.railway.app/api/v1/executions/webhook/dev.deployment/clone-staging-api/abc123" \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "demo-client",
    "source_environment": "production"
  }'
```

---

### 2. Check Execution Status

Poll for workflow execution status and results.

**Endpoint:**
```
GET /api/v1/executions/dev.deployment/clone-staging-api/{executionId}
```

**Response (Running):**
```json
{
  "id": "01HQRS...",
  "state": "RUNNING",
  "namespace": "dev.deployment",
  "flowId": "clone-staging-api",
  "startDate": "2024-01-12T10:30:00Z",
  "taskRunList": [
    {
      "taskId": "validate-inputs",
      "state": "SUCCESS"
    },
    {
      "taskId": "execute-clone",
      "state": "RUNNING"
    }
  ]
}
```

**Response (Success):**
```json
{
  "id": "01HQRS...",
  "state": "SUCCESS",
  "startDate": "2024-01-12T10:30:00Z",
  "endDate": "2024-01-12T10:30:25Z",
  "outputs": {
    "response": {
      "status": "success",
      "environment_name": "staging-demo-client-20240112-103000",
      "staging_url": "https://staging-demo.railway.app",
      "client_name": "demo-client",
      "source_environment": "production",
      "created_at": "2024-01-12T10:30:25Z"
    }
  }
}
```

**Example:**
```bash
curl "https://kestra.railway.app/api/v1/executions/dev.deployment/clone-staging-api/01HQRS..."
```

---

### 3. List Staging Environments

Retrieve all staging environments.

**Endpoint:**
```
POST /api/v1/executions/webhook/dev.deployment/list-staging-environments/{WEBHOOK_KEY}
```

**Request Body (Optional):**
```json
{
  "filter_prefix": "staging-"
}
```

**Response:**
```json
{
  "executionId": "01HQRT...",
  "state": "CREATED"
}
```

**After completion, fetch results:**
```bash
curl "https://kestra.railway.app/api/v1/executions/dev.deployment/list-staging-environments/{executionId}"
```

**Output:**
```json
{
  "state": "SUCCESS",
  "outputs": {
    "response": {
      "status": "success",
      "count": 3,
      "environments": [
        {
          "name": "staging-client-a",
          "id": "env-123",
          "createdAt": "2024-01-10T08:00:00Z"
        },
        {
          "name": "staging-client-b",
          "id": "env-456",
          "createdAt": "2024-01-11T14:30:00Z"
        }
      ],
      "queried_at": "2024-01-12T10:35:00Z"
    }
  }
}
```

**Example:**
```bash
curl -X POST "https://kestra.railway.app/api/v1/executions/webhook/dev.deployment/list-staging-environments/list-key-123"
```

---

### 4. Delete Staging Environment

Remove a staging environment (safety: only `staging-*` names allowed).

**Endpoint:**
```
POST /api/v1/executions/webhook/dev.deployment/delete-staging-environment/{WEBHOOK_KEY}
```

**Request Body:**
```json
{
  "environment_name": "staging-demo-client-20240112-103000"
}
```

**Response:**
```json
{
  "executionId": "01HQRU...",
  "state": "CREATED"
}
```

**After completion:**
```json
{
  "state": "SUCCESS",
  "outputs": {
    "response": {
      "status": "success",
      "environment_name": "staging-demo-client-20240112-103000",
      "message": "Environment deleted successfully",
      "deleted_at": "2024-01-12T10:40:00Z"
    }
  }
}
```

**Example:**
```bash
curl -X POST "https://kestra.railway.app/api/v1/executions/webhook/dev.deployment/delete-staging-environment/delete-key-789" \
  -H "Content-Type: application/json" \
  -d '{
    "environment_name": "staging-old-client"
  }'
```

---

## Frontend Integration Example

### JavaScript/TypeScript Client

```typescript
const KESTRA_API = "https://your-kestra.railway.app";
const CLONE_KEY = "your-clone-webhook-key";

async function createStaging(clientName: string) {
  // 1. Trigger clone
  const response = await fetch(
    `${KESTRA_API}/api/v1/executions/webhook/dev.deployment/clone-staging-api/${CLONE_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ client_name: clientName }),
    }
  );
  
  const { executionId } = await response.json();
  
  // 2. Poll for completion
  let status;
  do {
    await new Promise((resolve) => setTimeout(resolve, 3000));
    
    const statusRes = await fetch(
      `${KESTRA_API}/api/v1/executions/dev.deployment/clone-staging-api/${executionId}`
    );
    status = await statusRes.json();
    
    console.log("Status:", status.state);
  } while (status.state === "RUNNING" || status.state === "CREATED");
  
  if (status.state === "SUCCESS") {
    return status.outputs.response.staging_url;
  }
  
  throw new Error("Clone failed");
}

// Usage
const stagingUrl = await createStaging("acme-corp");
console.log("Staging ready:", stagingUrl);
```

---

## Error Handling

### Common Error States

**Execution Failed:**
```json
{
  "state": "FAILED",
  "failureReason": "Database sync error: connection timeout"
}
```

**Validation Error:**
```json
{
  "state": "FAILED",
  "taskRunList": [
    {
      "taskId": "validate-inputs",
      "state": "FAILED",
      "attempts": [
        {
          "logs": [
            "ERROR: client_name is required"
          ]
        }
      ]
    }
  ]
}
```

### Error Codes

| Error | Reason | Solution |
|-------|--------|----------|
| 401 Unauthorized | Invalid webhook key | Check webhook key in URL |
| 400 Bad Request | Missing required field | Include `client_name` |
| 500 Internal Error | Kestra/Railway issue | Check logs, retry |

---

## Rate Limits

- **Concurrent Executions:** 5 (configurable in Kestra)
- **API Requests:** Railway limits apply (~1000 req/hour)

---

## Webhook Security

1. **Keep webhook keys secret** - Store in environment variables
2. **Rotate keys periodically** - Generate new keys every 90 days
3. **Use HTTPS only** - Never send requests over HTTP
4. **Validate responses** - Check `state` before using outputs

---

## Support

- **Kestra Docs:** https://kestra.io/docs
- **Railway Docs:** https://docs.railway.app
- **Issues:** https://github.com/bonnelAI/Webdevai-infrastructure/issues
