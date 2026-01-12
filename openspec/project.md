# Project Context

## Purpose
Automated WordPress staging environment cloning system for agencies managing multiple client sites. Provides fast, reliable staging environment provisioning with production data synchronization.

## Tech Stack
- Railway (PaaS hosting platform)
- PostgreSQL (database)
- Bash (shell scripting)
- Railway CLI (infrastructure management)
- Kestra (workflow orchestration)
- Docker (containerization)
- WordPress (CMS)

## Project Conventions

### Code Style
- Bash scripts follow Google Shell Style Guide
- Use `set -euo pipefail` for error handling
- Prefer explicit error messages over silent failures
- Use kebab-case for file names and environment names
- Comment complex logic blocks with inline comments

### Architecture Patterns
- Imperative shell scripts over declarative IaC for speed
- Unix pipe streaming for data transfer (avoid disk I/O)
- Atomic operations with automatic rollback on failure
- CLI-first approach with optional workflow orchestration wrappers
- Idempotent operations where possible

### Testing Strategy
- Manual testing with representative database sizes (100MB, 500MB, 1GB)
- Failure scenario testing (network interruption, authentication errors)
- Performance benchmarking for database sync operations
- Integration testing with real Railway projects
- Validation of environment configuration fidelity

### Git Workflow
- Feature branches for new capabilities
- PR-based review process
- OpenSpec proposal required for new features
- Conventional commits (feat:, fix:, docs:, etc.)

## Domain Context
- WordPress agencies need isolated staging environments for client preview and testing
- Production sites contain live customer data requiring careful handling (GDPR)
- Database sizes typically range from 100MB to 5GB for WordPress sites
- Staging environments are temporary (usually 1-7 days lifespan)
- Multiple concurrent clones needed during high-activity periods (5-10 simultaneous)
- Agencies prioritize speed: manual processes take 5-15 minutes, target is <30 seconds

## Important Constraints
- Railway API rate limits (mitigated by CLI built-in retry logic)
- Network bandwidth bottleneck for database transfers (100-500 Mbps typical)
- PostgreSQL-only initially (MySQL support future enhancement)
- Database size practical limit: 5GB (larger requires different approach)
- Railway token security: must never commit tokens to Git
- Production data in staging: GDPR compliance required for EU clients

## External Dependencies
- Railway CLI (`railway`) - community-maintained provider for Railway infrastructure
- PostgreSQL client tools (`pg_dump`, `psql`) - native database streaming
- `jq` - JSON parsing for Railway CLI output
- Kestra - optional workflow orchestration platform
- Railway API - REST API for infrastructure management (via CLI)
