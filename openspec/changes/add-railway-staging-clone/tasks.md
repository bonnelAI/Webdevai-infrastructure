# Tasks: Automated Railway Staging Environment Cloning

## 1. Core Script Implementation
- [ ] 1.1 Create `scripts/` directory structure
- [ ] 1.2 Implement `clone_to_staging.sh` base script with argument parsing
- [ ] 1.3 Add input validation (environment name format, uniqueness check)
- [ ] 1.4 Implement Railway CLI environment creation (`railway environment new --duplicate`)
- [ ] 1.5 Implement database connection string extraction (JSON parsing with `jq`)
- [ ] 1.6 Implement database streaming sync (`pg_dump | psql` with error handling)
- [ ] 1.7 Implement domain assignment (`railway domain` command)
- [ ] 1.8 Add error handling and rollback logic (trap ERR signal)
- [ ] 1.9 Add progress logging with clear status indicators
- [ ] 1.10 Add script execution flags (`set -euo pipefail`)
- [ ] 1.11 Make script executable (`chmod +x`)

## 2. Script Testing & Validation
- [ ] 2.1 Test with small database (100MB) - verify speed and correctness
- [ ] 2.2 Test with medium database (500MB) - verify performance target (<20s)
- [ ] 2.3 Test with large database (1GB) - verify performance target (<30s)
- [ ] 2.4 Test failure scenarios (network interruption, invalid environment name)
- [ ] 2.5 Verify rollback functionality (staging environment deleted on failure)
- [ ] 2.6 Test environment variable replication (compare prod vs staging)
- [ ] 2.7 Verify domain assignment and accessibility

## 3. Documentation
- [ ] 3.1 Create `scripts/README.md` with usage instructions
- [ ] 3.2 Document prerequisites (Railway CLI, pg_dump, psql, jq)
- [ ] 3.3 Document environment setup (RAILWAY_TOKEN)
- [ ] 3.4 Add usage examples with different scenarios
- [ ] 3.5 Document error codes and troubleshooting steps
- [ ] 3.6 Add performance benchmarks table

## 4. Kestra Integration - Clone Workflow
- [ ] 4.1 Create `kestra/` directory structure
- [ ] 4.2 Implement `clone_staging_workflow.yaml` base structure
- [ ] 4.3 Add input validation task (environment name parameter)
- [ ] 4.4 Configure WorkingDirectory task for script execution
- [ ] 4.5 Add Railway CLI installation in beforeCommands
- [ ] 4.6 Configure PostgreSQL client tools installation
- [ ] 4.7 Implement shell task to execute `clone_to_staging.sh`
- [ ] 4.8 Configure environment variables (RAILWAY_TOKEN from secrets)
- [ ] 4.9 Add output capture and logging
- [ ] 4.10 Test workflow in Kestra UI

## 5. Kestra Integration - Deploy Workflow
- [ ] 5.1 Implement `deploy_to_railway.yaml` base structure
- [ ] 5.2 Add Git clone task (io.kestra.plugin.git.Clone)
- [ ] 5.3 Add Docker build task (io.kestra.plugin.docker.Build)
- [ ] 5.4 Configure Railway deployment commands (railway up)
- [ ] 5.5 Add database provisioning (railway add --database postgresql)
- [ ] 5.6 Configure container image (ubuntu:latest)
- [ ] 5.7 Add Railway CLI installation steps
- [ ] 5.8 Configure secrets (RAILWAY_TOKEN, project ID)
- [ ] 5.9 Test end-to-end deployment workflow

## 6. Error Handling & Edge Cases
- [ ] 6.1 Add pre-flight checks (Railway CLI installed, jq installed)
- [ ] 6.2 Add network connectivity check (ping Railway API)
- [ ] 6.3 Implement retry logic for database sync (3 attempts with backoff)
- [ ] 6.4 Add timeout handling for large database transfers
- [ ] 6.5 Implement graceful handling of duplicate environment names
- [ ] 6.6 Add validation for empty/corrupted database URLs
- [ ] 6.7 Test Railway API rate limiting scenarios

## 7. Observability & Logging
- [ ] 7.1 Add structured logging (timestamps, log levels)
- [ ] 7.2 Implement JSON output mode (`--json` flag) for machine parsing
- [ ] 7.3 Add execution metrics capture (start time, end time, duration)
- [ ] 7.4 Log database size before transfer
- [ ] 7.5 Sanitize database connection strings in logs (mask passwords)
- [ ] 7.6 Add success/failure exit codes (0 = success, 1 = failure)

## 8. Security Hardening
- [ ] 8.1 Document Railway token security best practices
- [ ] 8.2 Add checks to prevent accidental token logging
- [ ] 8.3 Implement connection string sanitization in all log output
- [ ] 8.4 Document staging environment access controls
- [ ] 8.5 Add warnings for production data in staging (GDPR notice)

## 9. Kestra REST API Implementation
- [ ] 9.1 Create `clone_staging_api.yaml` with webhook trigger
- [ ] 9.2 Implement input validation task (client_name, environment_name)
- [ ] 9.3 Add environment name sanitization and auto-generation
- [ ] 9.4 Configure webhook authentication (Bearer token or API key)
- [ ] 9.5 Implement WorkingDirectory task to execute clone script
- [ ] 9.6 Add output formatting task (JSON response with staging URL)
- [ ] 9.7 Test webhook endpoint with curl/Postman
- [ ] 9.8 Create `list_staging_environments.yaml` workflow
- [ ] 9.9 Create `delete_staging_environment.yaml` workflow
- [ ] 9.10 Document API endpoints and request/response formats
- [ ] 9.11 Configure CORS headers for frontend access
- [ ] 9.12 Test execution polling via Kestra API
- [ ] 9.13 Implement rate limiting (if not using Kestra's built-in)
- [ ] 9.14 Add API authentication documentation for frontend team

## 10. Frontend Integration
- [ ] 10.1 Create TypeScript/JavaScript API client example
- [ ] 10.2 Document webhook URL format and configuration
- [ ] 10.3 Implement execution status polling logic example
- [ ] 10.4 Add error handling examples for API client
- [ ] 10.5 Test API integration with sample frontend application
- [ ] 10.6 Document output format (staging_url, environment_name, etc.)
- [ ] 10.7 Create API usage examples for different scenarios
- [ ] 10.8 Test concurrent API requests (multiple simultaneous clones)

## 11. Integration Testing
- [ ] 11.1 Test script locally on developer machine
- [ ] 11.2 Test Kestra clone workflow end-to-end
- [ ] 11.3 Test Kestra deploy workflow end-to-end
- [ ] 11.4 Verify concurrent clone operations (2-3 simultaneous)
- [ ] 11.5 Test with real WordPress site (sample client data)
- [ ] 11.6 Verify domain accessibility after clone
- [ ] 11.7 Verify WordPress admin login in staging environment
- [ ] 11.8 Test API workflow from frontend trigger to completion
- [ ] 11.9 Verify API status polling and output retrieval
- [ ] 11.10 Test API error scenarios (invalid inputs, auth failures)

## 12. Production Readiness
- [ ] 12.1 Create operational runbook for team
- [ ] 12.2 Document monitoring and alerting setup
- [ ] 12.3 Create troubleshooting guide
- [ ] 12.4 Pilot with 3-5 client sites
- [ ] 12.5 Gather feedback and iterate
- [ ] 12.6 Deploy to production Kestra instance
- [ ] 12.7 Announce to team with training session
- [ ] 12.8 Train frontend team on API usage
- [ ] 12.9 Set up API monitoring and alerting

## 13. Future Enhancements (Backlog)
- [ ] 13.1 Implement health check after clone (HTTP ping)
- [ ] 13.2 Add auto-cleanup for staging environments >7 days old
- [ ] 13.3 Implement Slack/email notifications on clone complete
- [ ] 13.4 Add progress bar for database transfer (if feasible)
- [ ] 13.5 Create web UI for non-technical users
- [ ] 13.6 Implement data anonymization for PII scrubbing
- [ ] 13.7 Add WebSocket support for real-time progress updates
- [ ] 13.8 Implement API versioning (v2 endpoints)
- [ ] 13.9 Add GraphQL API alternative to REST

## Dependencies & Sequencing

**Critical Path**: 1 → 2 → 3 → 9 → 11 → 12

**Parallel Work Opportunities**:
- Tasks 4 and 5 can be implemented in parallel after Task 1 is complete
- Tasks 6 and 7 can be implemented in parallel after Task 2 is complete
- Task 8 can be done anytime after Task 1
- Tasks 9 (API) and 10 (Frontend) can be developed in parallel

**Blocking Dependencies**:
- Task 2 requires Task 1 complete (can't test without script)
- Task 4 and 5 require Task 1 complete (Kestra workflows call the script)
- Task 9 requires Task 4 complete (API uses Kestra workflows)
- Task 10 requires Task 9 complete (frontend needs API endpoints)
- Task 11 requires Tasks 1, 4, 5, and 9 complete (integration testing)
- Task 12 requires Task 11 complete (production deployment)

**Estimated Timeline**: 3-4 weeks
- Week 1: Tasks 1-3 (core script implementation and testing)
- Week 2: Tasks 4-7 (Kestra integration and observability)
- Week 3: Tasks 8-10 (security, API implementation, frontend integration)
- Week 4: Tasks 11-12 (integration testing, production deployment)
