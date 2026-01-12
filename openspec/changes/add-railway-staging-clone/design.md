# Design: Automated Railway Staging Environment Cloning

## Context

WordPress agencies managing multiple client sites need to create isolated staging environments quickly for:
- Testing updates before production deployment
- Client preview environments for approval workflows
- Development environments for feature work
- Debugging production issues without affecting live sites

**Current State**: Manual processes taking 5-15 minutes involving:
1. Manual Railway environment creation
2. Downloading database dumps (multi-GB files)
3. Uploading dumps to staging database
4. Manual subdomain configuration
5. Service restarts and verification

**Constraints**:
- Railway API limits (avoid rate limiting with CLI approach)
- Database sizes ranging from 100MB to 10GB
- Must support multiple concurrent clones (5-10 clients simultaneously)
- Zero downtime for production environments
- Must work in CI/CD pipelines (Kestra, GitHub Actions)

**Stakeholders**:
- Developers: Need fast, reliable cloning for daily work
- Agency operations: Need automation to reduce manual overhead
- Clients: Need preview environments within minutes of request

## Goals / Non-Goals

### Goals
1. **Speed**: Complete cloning in <30 seconds for typical WordPress databases (500MB-1GB)
2. **Zero Disk I/O**: Stream database content through memory to avoid bottlenecks
3. **Automation**: Single command or API call to trigger complete clone
4. **Reliability**: Atomic operations with automatic rollback on failure
5. **Observability**: Clear progress indicators and error messages
6. **Reproducibility**: Identical staging environments every time

### Non-Goals
1. **Cross-Platform Database Migration**: Only Postgres to Postgres (WordPress can use Postgres with plugins)
2. **Custom Backup Strategies**: Use Railway's native tooling, not custom backup solutions
3. **Multi-Cloud Support**: Railway-only initially (extensible later)
4. **Real-time Replication**: One-time snapshot clones, not continuous sync
5. **Schema Migrations**: Clone copies current schema as-is

## Decisions

### Decision 1: Railway CLI over Terraform

**Choice**: Use Railway CLI in imperative shell scripts

**Why**:
- **Performance**: CLI creates environments in 2-3 seconds vs Terraform's 30-60 second state refresh cycle
- **Simplicity**: No state files to manage or lock
- **Debugging**: Direct command output vs Terraform plan/apply abstractions
- **CI/CD Integration**: Shell scripts work everywhere; Terraform requires runners with state backends

**Alternatives Considered**:
- **Terraform**: Rejected due to state management overhead and slow refresh cycles
- **Railway API Direct**: Considered but CLI provides better error handling and authentication
- **Custom Go Tool**: Over-engineered for this use case; CLI already exists

**Trade-offs**:
- ✅ 10-20x faster execution
- ✅ No state drift issues
- ❌ Less declarative (can't audit "desired state" as easily)
- ❌ Requires Railway CLI installation on all execution environments

### Decision 2: Unix Pipe Streaming for Database Sync

**Choice**: Use `pg_dump $SOURCE | psql $TARGET` for data transfer

**Why**:
- **Speed**: Eliminates disk I/O bottleneck (10-50x faster than file-based methods)
- **Simplicity**: Single command, no cleanup required
- **Memory Efficient**: Streams in chunks, doesn't load entire database into RAM
- **Native Tooling**: Postgres client tools are battle-tested and universally available

**Alternatives Considered**:
- **File-based Dump/Restore**: 
  ```bash
  pg_dump $SOURCE > backup.sql  # writes to disk
  psql $TARGET < backup.sql      # reads from disk
  ```
  Rejected: 2-3x slower due to disk I/O, requires cleanup
  
- **Railway's Built-in Backups**: 
  Rejected: No API to restore to different environments automatically
  
- **Logical Replication**: 
  Rejected: Over-engineered; requires replication slots and ongoing maintenance

**Trade-offs**:
- ✅ 10-50x faster for databases >500MB
- ✅ Zero disk space requirements
- ✅ Atomic operation (fails if either command fails)
- ❌ No progress indicator during transfer (pg_dump doesn't show % complete in pipes)
- ❌ Requires network stability for duration of transfer

**Implementation Details**:
```bash
# Add flags for safety and speed
pg_dump \
  --no-owner \           # Don't copy ownership (staging uses different users)
  --no-privileges \      # Don't copy grants
  --clean \              # Drop existing objects in target
  --if-exists \          # Don't fail if objects don't exist
  --format=plain \       # Plain SQL for pipe compatibility
  "$SOURCE_URL" | psql "$TARGET_URL"
```

### Decision 3: Bash Script over Kestra-First

**Choice**: Implement core logic in `clone_to_staging.sh`, wrap with Kestra for orchestration

**Why**:
- **Portability**: Bash script runs locally, in CI, or anywhere
- **Debugging**: Developers can test locally without Kestra instance
- **Flexibility**: Kestra becomes optional orchestrator, not required dependency

**Architecture**:
```
clone_to_staging.sh (core logic)
    ↓
    ├─→ Local execution (developers)
    ├─→ Kestra workflow (automation)
    ├─→ GitHub Actions (CI/CD)
    └─→ API endpoint wrapper (future)
```

**Alternatives Considered**:
- **Kestra-Native Workflow**: Rejected; locks logic into Kestra platform
- **Python Script**: Considered but Bash is simpler for shell command orchestration
- **Node.js Script**: Over-engineered; Railway CLI already handles API complexity

**Trade-offs**:
- ✅ Works everywhere (developer laptops, CI, servers)
- ✅ Easy to debug with `bash -x`
- ✅ No additional runtime dependencies
- ❌ Bash error handling more verbose than higher-level languages
- ❌ JSON parsing requires `jq` (additional dependency)

### Decision 4: Kestra REST API for Frontend Integration

**Choice**: Use Kestra's built-in HTTP webhook triggers to expose clone operations as REST API endpoints

**Why**:
- **No Custom API Server**: Kestra provides production-ready REST API out of the box
- **Built-in Features**: Authentication, rate limiting, execution tracking, and logging included
- **Real-time Status**: Kestra's execution API provides live progress updates
- **Learning Opportunity**: Allows team to explore Kestra's capabilities beyond basic workflows

**How Kestra's API Works**:
```
Frontend → POST to Kestra Webhook → Trigger Workflow → Execute Bash Script → Return Execution ID
              ↓
         Poll GET /api/v1/executions/{id} → Get real-time status
```

**Alternatives Considered**:
- **Custom Express/FastAPI Server**: Rejected; requires maintaining separate service
- **AWS Lambda**: Rejected; adds cloud vendor dependency and complexity
- **Direct CLI Execution**: Rejected; no API layer for frontend integration

**Trade-offs**:
- ✅ Zero custom API code to maintain
- ✅ Built-in authentication, rate limiting, audit logs
- ✅ Real-time execution status via Kestra UI and API
- ✅ Webhook URLs are stable and versioned
- ❌ Requires Kestra instance running (already planned)
- ❌ Learning curve for Kestra-specific concepts

**Kestra API Endpoints**:
```
POST   {kestra}/api/v1/executions/webhook/{namespace}/{flow}/clone-key
GET    {kestra}/api/v1/executions/{namespace}/{flow}/{executionId}
GET    {kestra}/api/v1/executions/{namespace}/{flow}/{executionId}/logs
GET    {kestra}/api/v1/executions/{namespace}/{flow}
```

### Decision 5: Synchronous Operation with Progress Logging

**Choice**: Block script execution during clone, emit progress logs

**Why**:
- **Simplicity**: Caller knows exactly when clone completes
- **Error Handling**: Immediate failure detection
- **Debugging**: Sequential logs easy to trace

**Alternatives Considered**:
- **Async with Webhooks**: Rejected for initial implementation; adds complexity
- **Background Jobs**: Could be added later as wrapper around synchronous script

**Trade-offs**:
- ✅ Simple error handling
- ✅ Clear success/failure states
- ❌ Blocks caller for 20-30 seconds
- ❌ No progress bar for database transfer (technical limitation of pg_dump pipes)

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     User / API / Kestra                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              clone_to_staging.sh (Orchestrator)             │
│  • Validates inputs                                         │
│  • Creates Railway environment                              │
│  • Extracts connection strings                              │
│  • Orchestrates database sync                               │
│  • Assigns domain                                           │
│  • Rollback on failure                                      │
└───────┬────────────────────────┬────────────────────────────┘
        │                        │
        ▼                        ▼
┌──────────────────┐    ┌──────────────────────────┐
│   Railway CLI    │    │   PostgreSQL Clients     │
│  • environment   │    │  • pg_dump (source)      │
│  • variables     │    │  • psql (target)         │
│  • domain        │    │  • Unix pipe streaming   │
└──────────────────┘    └──────────────────────────┘
        │                        │
        ▼                        ▼
┌─────────────────────────────────────────────────────────────┐
│                      Railway Platform                        │
│  • Environments (prod, staging-*)                           │
│  • Services (web, database)                                 │
│  • Domains (*.railway.app, custom)                          │
└─────────────────────────────────────────────────────────────┘
```

### Execution Flow

```
1. User invokes script: ./clone_to_staging.sh staging-client-alpha
   ↓
2. Validate inputs (environment name unique, source exists)
   ↓
3. Railway CLI: Create environment
   $ railway environment new staging-client-alpha --duplicate production
   ↓
4. Extract database URLs via JSON output
   $ railway variables --environment production --json | jq -r .DATABASE_URL
   ↓
5. Stream database content (Unix pipe)
   $ pg_dump $SOURCE_URL | psql $TARGET_URL
   ↓
6. Assign Railway domain
   $ railway domain --environment staging-client-alpha
   ↓
7. Emit success message with domain URL
```

### Error Handling Strategy

```bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Trap cleanup on failure
cleanup_on_failure() {
  echo "❌ Clone failed. Rolling back..."
  railway environment delete "$NEW_ENV" --yes 2>/dev/null || true
  exit 1
}
trap cleanup_on_failure ERR

# Validate before each step
validate_step() {
  if ! command_succeeded; then
    echo "ERROR: Step X failed"
    return 1
  fi
}
```

## Data Flow

### Database Sync Detail

```
Production DB (Railway)
    ↓
pg_dump (client machine)
    ↓ [TCP connection]
    ↓ [Memory buffer: 8MB chunks]
    ↓ [Unix pipe]
    ↓
psql (client machine)
    ↓ [TCP connection]
    ↓
Staging DB (Railway)
```

**Key Point**: Data never touches disk on client machine. Entire transfer happens through memory buffers.

**Performance Characteristics**:
- 100MB database: ~5 seconds
- 500MB database: ~15 seconds
- 1GB database: ~25 seconds
- 5GB database: ~2 minutes

Bottleneck: Network bandwidth between client and Railway (typically 100-500 Mbps)

## Kestra REST API Architecture

### API Flow with Kestra Webhooks

```
┌─────────────┐
│  Frontend   │
│  (React/    │
│   Vue/etc)  │
└──────┬──────┘
       │ POST /api/v1/executions/webhook/dev.deployment/clone-staging-api/abc123
       │ Body: {client_name: "client-alpha", enable_basic_auth: true}
       ▼
┌─────────────────────────────────────────────────────────┐
│              Kestra API Server                          │
│  • Validates webhook key                                │
│  • Authenticates request (Bearer token)                 │
│  • Creates new execution                                │
│  • Returns execution ID immediately (202 Accepted)      │
└──────┬──────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│         Kestra Workflow: clone-staging-api.yaml         │
│                                                         │
│  1. validate-inputs (task)                              │
│     • Check client_name not empty                       │
│     • Sanitize environment_name                         │
│     • Set defaults for optional params                  │
│                                                         │
│  2. execute-clone (WorkingDirectory)                    │
│     • Install Railway CLI & dependencies                │
│     • Copy clone_to_staging.sh script                   │
│     • Execute: ./clone_to_staging.sh {{inputs.env}}    │
│     • Capture stdout/stderr                             │
│                                                         │
│  3. extract-outputs (task)                              │
│     • Parse staging URL from script output              │
│     • Extract execution metrics                         │
│     • Format response JSON                              │
└──────┬──────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────┐
│         clone_to_staging.sh (Bash Script)            │
│  • Creates Railway environment                       │
│  • Streams database via pg_dump | psql               │
│  • Assigns domain                                    │
│  • Returns: STAGING_URL=https://staging-x.railway...│
└──────┬───────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────┐
│             Railway Platform                         │
│  • New environment created                           │
│  • Database synced                                   │
│  • Domain assigned                                   │
└──────────────────────────────────────────────────────┘

Frontend Polling Loop:
  ┌─→ GET /api/v1/executions/{namespace}/{flow}/{executionId}
  │   Response: {state: "RUNNING", tasks: [{name: "sync-database", state: "RUNNING"}]}
  │   
  └─ Poll every 2-5 seconds until state = "SUCCESS" or "FAILED"
     Final Response: {state: "SUCCESS", outputs: {staging_url: "https://..."}}
```

### Kestra Workflow YAML Structure

**File: `kestra/clone_staging_api.yaml`**

```yaml
id: clone-staging-api
namespace: dev.deployment

description: |
  REST API endpoint for frontend-triggered staging environment cloning.
  Exposes HTTP webhook that accepts clone parameters and returns execution ID.

triggers:
  - id: webhook-trigger
    type: io.kestra.plugin.core.trigger.Webhook
    key: abc123  # Secret webhook key (regenerate for production)

inputs:
  - id: client_name
    type: STRING
    required: true
    description: "Client identifier (used in environment naming)"
  
  - id: environment_name
    type: STRING
    required: false
    description: "Custom environment name (auto-generated if not provided)"
  
  - id: source_environment
    type: STRING
    defaults: production
    description: "Source environment to clone from"
  
  - id: custom_domain
    type: STRING
    required: false
    description: "Custom domain for staging (optional)"
  
  - id: enable_basic_auth
    type: BOOLEAN
    defaults: false
    description: "Enable HTTP basic authentication"
  
  - id: wordpress_url_replace
    type: BOOLEAN
    defaults: true
    description: "Run wp search-replace for URLs"

tasks:
  - id: validate-inputs
    type: io.kestra.plugin.scripts.shell.Commands
    containerImage: ubuntu:latest
    commands:
      - |
        # Validate client_name
        if [ -z "{{inputs.client_name}}" ]; then
          echo "ERROR: client_name is required"
          exit 1
        fi
        
        # Generate environment name if not provided
        if [ -z "{{inputs.environment_name}}" ]; then
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          ENV_NAME="staging-{{inputs.client_name}}-${TIMESTAMP}"
        else
          ENV_NAME="{{inputs.environment_name}}"
        fi
        
        # Sanitize: lowercase, replace invalid chars
        ENV_NAME=$(echo "$ENV_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
        
        echo "VALIDATED_ENV_NAME=$ENV_NAME" >> {{outputDir}}/vars.txt
        echo "Validated environment name: $ENV_NAME"

  - id: execute-clone
    type: io.kestra.plugin.core.flow.WorkingDirectory
    tasks:
      - id: install-dependencies
        type: io.kestra.plugin.scripts.shell.Commands
        containerImage: ubuntu:latest
        beforeCommands:
          - apt-get update
          - apt-get install -y curl jq postgresql-client
          - curl -fsSL https://railway.app/install.sh | sh
        env:
          RAILWAY_TOKEN: "{{secret('RAILWAY_TOKEN')}}"
        commands:
          - railway --version
          - pg_dump --version
      
      - id: run-clone-script
        type: io.kestra.plugin.scripts.shell.Script
        containerImage: ubuntu:latest
        env:
          RAILWAY_TOKEN: "{{secret('RAILWAY_TOKEN')}}"
          SOURCE_ENV: "{{inputs.source_environment}}"
          NEW_ENV: "{{outputs.validate-inputs.vars.VALIDATED_ENV_NAME}}"
          CUSTOM_DOMAIN: "{{inputs.custom_domain}}"
          ENABLE_BASIC_AUTH: "{{inputs.enable_basic_auth}}"
        script: |
          #!/bin/bash
          set -euo pipefail
          
          # This would be the clone_to_staging.sh script content
          # Or mount the script from a Git repository
          
          echo "🚀 Starting clone of $SOURCE_ENV to $NEW_ENV..."
          
          # 1. Create environment
          railway environment new "$NEW_ENV" --duplicate "$SOURCE_ENV"
          
          # 2. Extract connection strings
          SOURCE_URL=$(railway variables --environment "$SOURCE_ENV" --service database --json | jq -r .DATABASE_URL)
          TARGET_URL=$(railway variables --environment "$NEW_ENV" --service database --json | jq -r .DATABASE_URL)
          
          # 3. Stream database
          echo "🔄 Streaming database..."
          pg_dump --no-owner --no-privileges --clean --if-exists "$SOURCE_URL" | psql "$TARGET_URL"
          
          # 4. Assign domain
          DOMAIN=$(railway domain --environment "$NEW_ENV" --json | jq -r .domain)
          
          echo "✨ Success! Staging URL: https://$DOMAIN"
          echo "STAGING_URL=https://$DOMAIN" >> {{outputDir}}/outputs.txt
          echo "ENV_NAME=$NEW_ENV" >> {{outputDir}}/outputs.txt

  - id: format-response
    type: io.kestra.plugin.scripts.shell.Commands
    commands:
      - |
        cat <<EOF > {{outputDir}}/response.json
        {
          "status": "success",
          "environment_name": "{{outputs['execute-clone'].vars.ENV_NAME}}",
          "staging_url": "{{outputs['execute-clone'].vars.STAGING_URL}}",
          "client_name": "{{inputs.client_name}}",
          "created_at": "$(date -Iseconds)"
        }
        EOF

outputs:
  - id: response
    type: JSON
    value: "{{outputs['format-response'].outputFiles['response.json']}}"
```

### Frontend Integration Example

**JavaScript/TypeScript Client:**

```typescript
const KESTRA_BASE_URL = 'https://your-kestra.com';
const WEBHOOK_KEY = 'abc123';  // Store in .env
const API_TOKEN = 'your-api-token';  // Kestra API token

// 1. Trigger clone operation
async function createStagingEnvironment(clientName: string, options = {}) {
  const response = await fetch(
    `${KESTRA_BASE_URL}/api/v1/executions/webhook/dev.deployment/clone-staging-api/${WEBHOOK_KEY}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_TOKEN}`
      },
      body: JSON.stringify({
        client_name: clientName,
        enable_basic_auth: options.basicAuth || false,
        custom_domain: options.customDomain || null
      })
    }
  );
  
  const data = await response.json();
  return data.executionId;  // "01HQRS..."
}

// 2. Poll for execution status
async function pollExecutionStatus(executionId: string) {
  const response = await fetch(
    `${KESTRA_BASE_URL}/api/v1/executions/dev.deployment/clone-staging-api/${executionId}`,
    {
      headers: {
        'Authorization': `Bearer ${API_TOKEN}`
      }
    }
  );
  
  const execution = await response.json();
  
  return {
    state: execution.state,  // RUNNING, SUCCESS, FAILED
    tasks: execution.taskRunList.map(t => ({
      name: t.taskId,
      state: t.state,
      duration: t.duration
    })),
    outputs: execution.outputs  // {staging_url: "...", environment_name: "..."}
  };
}

// 3. Complete flow with UI updates
async function cloneWithProgress(clientName: string) {
  // Start clone
  const executionId = await createStagingEnvironment(clientName);
  console.log('Clone started:', executionId);
  
  // Poll every 3 seconds
  const pollInterval = setInterval(async () => {
    const status = await pollExecutionStatus(executionId);
    
    console.log('Status:', status.state);
    console.log('Tasks:', status.tasks);
    
    if (status.state === 'SUCCESS') {
      clearInterval(pollInterval);
      console.log('✅ Staging ready:', status.outputs.staging_url);
      // Show success notification to user
    }
    
    if (status.state === 'FAILED') {
      clearInterval(pollInterval);
      console.error('❌ Clone failed');
      // Show error message to user
    }
  }, 3000);
}
```

### Additional Kestra Workflows for API

**List Staging Environments: `kestra/list_staging_environments.yaml`**

```yaml
id: list-staging-environments
namespace: dev.deployment

triggers:
  - id: webhook-list
    type: io.kestra.plugin.core.trigger.Webhook
    key: list-key

tasks:
  - id: query-environments
    type: io.kestra.plugin.scripts.shell.Commands
    env:
      RAILWAY_TOKEN: "{{secret('RAILWAY_TOKEN')}}"
    commands:
      - railway environment list --json > {{outputDir}}/environments.json
      
  - id: filter-staging
    type: io.kestra.plugin.scripts.shell.Commands
    commands:
      - |
        jq '[.[] | select(.name | startswith("staging-"))]' \
          {{outputs['query-environments'].outputFiles['environments.json']}} \
          > {{outputDir}}/staging.json

outputs:
  - id: staging_environments
    type: JSON
    value: "{{outputs['filter-staging'].outputFiles['staging.json']}}"
```

**Delete Staging Environment: `kestra/delete_staging_environment.yaml`**

```yaml
id: delete-staging-environment
namespace: dev.deployment

triggers:
  - id: webhook-delete
    type: io.kestra.plugin.core.trigger.Webhook
    key: delete-key

inputs:
  - id: environment_name
    type: STRING
    required: true

tasks:
  - id: validate-staging
    type: io.kestra.plugin.scripts.shell.Commands
    commands:
      - |
        if [[ ! "{{inputs.environment_name}}" =~ ^staging- ]]; then
          echo "ERROR: Can only delete staging environments"
          exit 1
        fi
  
  - id: delete-environment
    type: io.kestra.plugin.scripts.shell.Commands
    env:
      RAILWAY_TOKEN: "{{secret('RAILWAY_TOKEN')}}"
    commands:
      - railway environment delete "{{inputs.environment_name}}" --yes
      - echo "Deleted: {{inputs.environment_name}}"
```

## Risks / Trade-offs

### Risk 1: Network Interruption During Database Transfer
**Impact**: High - corrupted staging database
**Likelihood**: Medium - depends on network stability

**Mitigation**:
- Use `--clean --if-exists` flags in pg_dump to make operation idempotent
- Implement retry logic (3 attempts with exponential backoff)
- Add pre-flight network check (ping Railway endpoints)

**Rollback**: Delete staging environment and retry

### Risk 2: Railway API Rate Limiting
**Impact**: Medium - failed clone operations during high volume
**Likelihood**: Low - CLI includes built-in rate limit handling

**Mitigation**:
- Railway CLI already implements retry with backoff
- Add queue system if scaling beyond 10 concurrent clones (future enhancement)
- Monitor Railway API usage in observability layer

### Risk 3: Large Database Timeouts
**Impact**: Medium - clone fails for databases >5GB
**Likelihood**: Medium - some WordPress sites have large media libraries in DB

**Mitigation**:
- Document size limitations clearly (recommend <2GB for optimal performance)
- Add `--verbose` flag to pg_dump for progress visibility
- Consider chunked transfer approach for >5GB databases (future enhancement)
- Alternative: Use Railway's backup/restore for very large databases

### Risk 4: Concurrent Clone Conflicts
**Impact**: Low - environment name collisions
**Likelihood**: Low - enforced unique naming

**Mitigation**:
- Check environment exists before creation: `railway environment list | grep $NAME`
- Auto-generate unique names with timestamps if collision detected
- Return error with suggested alternative name

### Risk 5: Incomplete Environment Variable Replication
**Impact**: High - staging app misconfigured
**Likelihood**: Very Low - Railway's `--duplicate` flag copies all vars

**Mitigation**:
- Add post-clone validation step: compare variable count between prod and staging
- Emit warning if variable mismatch detected
- Provide `--verify` flag for deep validation

## Migration Plan

### Phase 1: Core Script Implementation (Week 1)
1. Implement `clone_to_staging.sh` with:
   - Environment creation
   - Database streaming sync
   - Domain assignment
   - Error handling and rollback
2. Manual testing with 3 sample WordPress databases (100MB, 500MB, 1GB)
3. Document script usage in README

### Phase 2: Kestra Integration (Week 1-2)
1. Create `kestra/clone_staging_workflow.yaml`:
   - Trigger via API call
   - Input validation
   - Execute shell script in container
   - Emit success/failure events
2. Create `kestra/deploy_to_railway.yaml` (GitHub → Docker → Railway)
3. Test end-to-end workflow

### Phase 3: Observability & Monitoring (Week 2)
1. Add structured logging (JSON output mode)
2. Capture execution metrics (duration, database size, success rate)
3. Integrate with monitoring system (future: send to Datadog/Grafana)

### Phase 4: Production Rollout (Week 3)
1. Test with 5 pilot client sites
2. Create operational runbook
3. Train team on usage
4. Deploy to production Kestra instance

### Rollback Plan
If critical issues discovered:
1. Revert to manual cloning process
2. Document failure mode for investigation
3. Keep script in repository for future refinement

**Decision Point**: After Phase 1, validate performance targets met before proceeding.

## Open Questions

1. **Q**: Should we support MySQL/MariaDB for WordPress sites not using Postgres?
   **A**: Deferred to v2. Initial implementation Postgres-only. Most modern WordPress hosts support Postgres via plugins.

2. **Q**: How to handle media files (uploads directory)?
   **A**: Railway's environment duplication includes persistent volumes. Media files automatically cloned with container filesystem. For S3-backed media, staging environment variables point to separate S3 bucket (configured in Railway).

3. **Q**: Should we implement health checks after cloning?
   **A**: Yes - add in Phase 3. Simple HTTP check to staging domain to verify app responds.

4. **Q**: How to handle long-running migrations or post-clone scripts?
   **A**: Out of scope for initial implementation. WordPress sites rarely need post-clone scripts. If needed, add `--post-clone-script` flag in v2.

5. **Q**: Should staging environments auto-delete after X days?
   **A**: Yes, but implement separately. Add cron job or Kestra scheduled workflow to delete staging environments older than 7 days (with whitelist for permanent staging).

## Performance Targets

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Total clone time (500MB DB) | <20 seconds | Start to finish script execution |
| Total clone time (1GB DB) | <30 seconds | Start to finish script execution |
| Database sync speed | >50 MB/sec | Monitor pg_dump throughput |
| Environment creation | <5 seconds | Railway CLI response time |
| Configuration fidelity | 100% | Variable count match prod vs staging |
| Success rate | >95% | Clone attempts vs successful completions |

## Security Considerations

1. **Railway API Token Storage**:
   - Store in environment variable (`RAILWAY_TOKEN`)
   - Never commit to Git
   - Use secret management in Kestra (built-in secrets)

2. **Database Connection Strings**:
   - Extract at runtime, never log full connection strings
   - Sanitize logs (mask passwords)

3. **Staging Environment Access**:
   - Staging domains publicly accessible (Railway default)
   - Add HTTP basic auth for sensitive clients (Railway supports this)
   - Document security best practices

4. **Data Privacy**:
   - Staging environments contain production data (PII)
   - Document GDPR implications
   - Consider anonymization script for staging data (future enhancement)

## Future Enhancements

1. **Parallel Cloning**: Clone multiple environments simultaneously
2. **Incremental Sync**: Update existing staging with latest prod data (don't recreate)
3. **Custom Domain Support**: Assign client-specific domains (e.g., `staging.clientsite.com`)
4. **Health Check Integration**: Verify WordPress site loads after clone
5. **Anonymization Pipeline**: Scrub PII from staging databases automatically
6. **Cost Tracking**: Monitor Railway usage per staging environment
7. **Auto-Cleanup**: Delete staging environments after 7 days automatically
8. **Slack/Email Notifications**: Alert when clone completes or fails
9. **MySQL Support**: Extend to WordPress sites using MySQL
10. **Terraform Module**: Wrap script in Terraform module for IaC workflows (if demand exists)
