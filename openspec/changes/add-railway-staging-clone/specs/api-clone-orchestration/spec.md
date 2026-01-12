# API Clone Orchestration Specification

## ADDED Requirements

### Requirement: Kestra HTTP Trigger for Clone Operations
The system SHALL expose a Kestra workflow with HTTP webhook trigger that accepts clone requests via REST API and returns job execution details.

#### Scenario: Trigger clone via HTTP POST
- **WHEN** a frontend POST request is sent to the Kestra webhook URL
- **THEN** Kestra creates a new workflow execution
- **AND** returns a 202 Accepted response with execution ID
- **AND** the execution ID can be used to poll for status

#### Scenario: Accept JSON payload with clone parameters
- **WHEN** the HTTP request includes JSON body with client_name and options
- **THEN** Kestra extracts inputs from the request body
- **AND** passes parameters to the clone workflow as variables
- **AND** validates required fields before execution

#### Scenario: Return execution URL for polling
- **WHEN** workflow execution starts
- **THEN** the response includes the Kestra execution URL
- **AND** the URL format is /api/v1/executions/{namespace}/{flowId}/{executionId}
- **AND** the frontend can poll this URL for status updates

### Requirement: Input Validation and Sanitization
The system SHALL validate all API inputs before executing clone operations to prevent errors and security issues.

#### Scenario: Validate required fields
- **WHEN** an API request is received
- **THEN** Kestra validates that client_name is provided
- **AND** validates that railway_project_id is provided (or uses default from secrets)
- **AND** returns 400 Bad Request if required fields are missing

#### Scenario: Sanitize environment name
- **WHEN** environment_name is provided in the request
- **THEN** the system validates it matches pattern ^[a-z][a-z0-9-]{2,49}$
- **AND** converts to lowercase if uppercase characters present
- **AND** replaces invalid characters with hyphens

#### Scenario: Auto-generate environment name
- **WHEN** environment_name is not provided
- **THEN** the system generates a name using pattern staging-{client_name}-{timestamp}
- **AND** ensures the generated name is unique
- **AND** logs the generated name in execution output

#### Scenario: Validate Railway project access
- **WHEN** railway_project_id is provided
- **THEN** the system verifies RAILWAY_TOKEN has access to the project
- **AND** fails fast with clear error if authentication fails
- **AND** logs the validation step

### Requirement: Asynchronous Execution with Status Polling
The system SHALL execute clone operations asynchronously and provide real-time status updates via Kestra's execution API.

#### Scenario: Immediate response on request acceptance
- **WHEN** a clone request is accepted
- **THEN** Kestra returns HTTP 202 within 1 second
- **AND** the response includes execution ID and polling URL
- **AND** the workflow execution begins immediately

#### Scenario: Poll execution status
- **WHEN** the frontend polls the execution URL
- **THEN** Kestra returns current execution state (RUNNING, SUCCESS, FAILED)
- **AND** includes task-level status (environment creation, database sync, domain assignment)
- **AND** provides elapsed time and estimated completion

#### Scenario: Real-time log streaming
- **WHEN** execution is in progress
- **THEN** Kestra's API provides access to task logs
- **AND** logs are streamed in real-time via GET /api/v1/executions/{id}/logs
- **AND** logs include timestamps and task names

#### Scenario: Completion notification
- **WHEN** clone operation completes successfully
- **THEN** execution state changes to SUCCESS
- **AND** output includes staging environment URL
- **AND** output includes database sync duration and success metrics

### Requirement: Error Handling and Failure Reporting
The system SHALL provide detailed error information through the Kestra API when clone operations fail.

#### Scenario: Task-level failure reporting
- **WHEN** any task in the workflow fails
- **THEN** execution state changes to FAILED
- **AND** the failed task is identified with name and error message
- **AND** previous successful tasks are marked as COMPLETED

#### Scenario: Rollback status reporting
- **WHEN** automatic rollback is triggered
- **THEN** a rollback task is added to the execution
- **AND** rollback status is visible in the API response
- **AND** logs indicate which environment was deleted

#### Scenario: Retry status tracking
- **WHEN** database sync is retried due to transient failure
- **THEN** each retry attempt is logged as a separate task attempt
- **AND** the API shows retry count and next retry time
- **AND** final failure is reported after max retries exceeded

### Requirement: Kestra Webhook Authentication
The system SHALL secure the HTTP webhook endpoint with authentication to prevent unauthorized clone operations.

#### Scenario: Bearer token authentication
- **WHEN** a frontend makes an API request
- **THEN** the request must include Authorization: Bearer {token} header
- **AND** Kestra validates the token against configured secrets
- **AND** returns 401 Unauthorized if token is missing or invalid

#### Scenario: API key authentication alternative
- **WHEN** using API key authentication
- **THEN** the request includes X-API-Key header
- **AND** Kestra validates against stored API keys
- **AND** each API key can be scoped to specific namespaces

#### Scenario: Rate limiting per API key
- **WHEN** an API key makes multiple requests
- **THEN** Kestra enforces rate limits (e.g., 10 clones per hour)
- **AND** returns 429 Too Many Requests when limit exceeded
- **AND** includes Retry-After header with wait time

### Requirement: Response Format Standardization
The system SHALL return consistent JSON response formats for all API endpoints following REST conventions.

#### Scenario: Successful clone initiation response
- **WHEN** clone request is accepted
- **THEN** response format is:
```json
{
  "status": "accepted",
  "execution_id": "01HQRS...",
  "polling_url": "/api/v1/executions/dev.deployment/clone-staging/01HQRS...",
  "namespace": "dev.deployment",
  "flow_id": "clone-staging-api",
  "estimated_completion": "2026-01-12T11:35:00Z"
}
```

#### Scenario: Execution status response
- **WHEN** polling for execution status
- **THEN** response includes current state and task progress:
```json
{
  "execution_id": "01HQRS...",
  "state": "RUNNING",
  "start_date": "2026-01-12T11:32:00Z",
  "tasks": [
    {"name": "validate-inputs", "state": "SUCCESS", "duration": "0.5s"},
    {"name": "create-environment", "state": "SUCCESS", "duration": "3.2s"},
    {"name": "sync-database", "state": "RUNNING", "duration": "12.1s"},
    {"name": "assign-domain", "state": "CREATED"}
  ]
}
```

#### Scenario: Error response format
- **WHEN** an error occurs
- **THEN** response follows standard error format:
```json
{
  "error": "ValidationError",
  "message": "Invalid environment name: must start with lowercase letter",
  "details": {
    "field": "environment_name",
    "provided": "123-staging",
    "pattern": "^[a-z][a-z0-9-]{2,49}$"
  }
}
```

### Requirement: Frontend Integration Support
The system SHALL provide API features that enable seamless frontend integration with clear documentation.

#### Scenario: CORS headers for browser requests
- **WHEN** a browser makes a request to the Kestra API
- **THEN** Kestra includes CORS headers in the response
- **AND** Access-Control-Allow-Origin is configured for frontend domain
- **AND** preflight OPTIONS requests are handled correctly

#### Scenario: Webhook URL discovery
- **WHEN** the frontend needs the webhook URL
- **THEN** the URL is documented and stable
- **AND** follows pattern: {kestra_base_url}/api/v1/executions/webhook/{namespace}/{flow_id}/{webhook_key}
- **AND** webhook_key is stored in frontend configuration

#### Scenario: Output data extraction
- **WHEN** execution completes successfully
- **THEN** the API provides outputs as JSON
- **AND** outputs include: staging_url, environment_name, database_size, duration
- **AND** frontend can extract and display these values

### Requirement: Multiple Environment Management via API
The system SHALL expose Kestra endpoints to list, query, and delete staging environments created via the API.

#### Scenario: List all staging environments
- **WHEN** frontend requests list of staging environments
- **THEN** Kestra workflow queries Railway CLI for environments
- **AND** returns JSON array of environments with metadata
- **AND** includes: name, created_at, domain, status

#### Scenario: Get specific environment details
- **WHEN** frontend requests details for a specific environment
- **THEN** Kestra workflow queries Railway for environment info
- **AND** returns full environment configuration and services
- **AND** includes database size and last updated timestamp

#### Scenario: Delete staging environment via API
- **WHEN** frontend sends DELETE request with environment name
- **THEN** Kestra triggers environment deletion workflow
- **AND** Railway environment and associated resources are removed
- **AND** returns confirmation with deletion timestamp

### Requirement: Workflow Parameterization
The system SHALL support flexible workflow configuration through Kestra inputs to accommodate different use cases.

#### Scenario: Optional custom domain parameter
- **WHEN** custom_domain is provided in request
- **THEN** the workflow passes this to domain assignment task
- **AND** validates domain format before use
- **AND** falls back to Railway domain if validation fails

#### Scenario: WordPress URL replacement flag
- **WHEN** wordpress_url_replace is true in request
- **THEN** the workflow executes wp search-replace command
- **AND** updates all production URLs to staging URLs
- **AND** logs the number of URLs replaced

#### Scenario: Basic auth configuration
- **WHEN** enable_basic_auth is true in request
- **THEN** the workflow generates random credentials
- **AND** sets HTTP_AUTH_USER and HTTP_AUTH_PASSWORD in Railway
- **AND** returns credentials in execution output (encrypted)

#### Scenario: Source environment selection
- **WHEN** source_environment is specified (default: production)
- **THEN** the workflow clones from the specified environment
- **AND** validates source environment exists
- **AND** fails with clear error if source not found

### Requirement: Execution History and Audit Trail
The system SHALL maintain execution history through Kestra's built-in storage for auditing and troubleshooting.

#### Scenario: Query execution history
- **WHEN** requesting execution history for the clone workflow
- **THEN** Kestra returns paginated list of past executions
- **AND** includes execution date, status, inputs, and outputs
- **AND** supports filtering by date range and status

#### Scenario: Execution retention
- **WHEN** executions are stored
- **THEN** Kestra retains execution data for configured period (default: 30 days)
- **AND** logs are compressed after 7 days
- **AND** old executions are automatically purged

#### Scenario: Audit trail for compliance
- **WHEN** auditing clone operations
- **THEN** each execution records who initiated it (API key/token)
- **AND** records all input parameters and timestamps
- **AND** logs are immutable and tamper-evident
