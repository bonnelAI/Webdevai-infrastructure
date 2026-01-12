# Change: Automated Railway Staging Environment Cloning

## Why

WordPress agencies need to clone production client sites into isolated staging environments instantly for testing, development, and client previews. Current manual approaches are slow (5-15 minutes per clone) and error-prone. Terraform-based solutions introduce state management overhead that makes on-demand cloning impractical at scale.

The existing pain points:
- Manual environment setup wastes developer time
- Database snapshots require downloading multi-GB files to disk
- Subdomain routing must be configured manually per client
- No standardized cloning workflow leads to inconsistent staging environments

## What Changes

This change introduces a **fast, imperative cloning system** using Railway CLI and native Postgres streaming to create isolated staging environments in under 30 seconds.

Core capabilities:
- **Environment Duplication**: Clone Railway production environments with all service configurations, environment variables, and Docker images automatically replicated
- **Zero-Disk Database Sync**: Stream production database content directly to staging using Unix pipes (`pg_dump | psql`) without intermediate file storage
- **Automatic Subdomain Assignment**: Generate Railway-hosted domains or custom subdomains for each staging environment
- **Shell Script Orchestration**: Single executable script (`clone_to_staging.sh`) that chains Railway CLI commands for one-command cloning

Technical approach:
- Leverage Railway's native `environment new --duplicate` for instant service replication
- Use PostgreSQL native tools for memory-streamed data transfer (10-50x faster than file-based approaches)
- Containerize operations for consistency across development machines
- Integrate with Kestra workflows for automation and orchestration

**Performance Target**: Complete clone operation (environment + database + domain) in <30 seconds for databases up to 1GB.

## Impact

### Affected Capabilities (New)
- `environment-cloning` - Railway environment duplication and isolation
- `database-sync` - Fast PostgreSQL streaming replication
- `subdomain-routing` - Automatic domain assignment for staging environments
- `api-clone-orchestration` - Kestra REST API for frontend-triggered cloning

### Affected Code
- New scripts:
  - `scripts/clone_to_staging.sh` - Main cloning orchestration script
  - `kestra/deploy_to_railway.yaml` - Kestra workflow for automated deployments
  - `kestra/clone_staging_workflow.yaml` - Kestra workflow for on-demand cloning
  - `kestra/clone_staging_api.yaml` - Kestra HTTP webhook workflow for API access
  - `kestra/list_staging_environments.yaml` - API endpoint to list environments
  - `kestra/delete_staging_environment.yaml` - API endpoint to delete environments

### Dependencies
- Railway CLI (`railway`)
- PostgreSQL client tools (`pg_dump`, `psql`)
- `jq` for JSON parsing
- `bash` 4.0+ or compatible shell
- Railway project with production environment configured

### Breaking Changes
None - this is a new capability with no modifications to existing systems.

### Migration Path
Not applicable (greenfield implementation).

### Success Metrics
- Clone operation completes in <30 seconds for 1GB databases
- Zero intermediate disk writes during database sync
- 100% environment variable and service configuration fidelity
- Automatic rollback on failure (staging environment deleted if sync fails)
