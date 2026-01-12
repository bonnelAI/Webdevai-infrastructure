# Database Sync Specification

## ADDED Requirements

### Requirement: PostgreSQL Streaming Replication
The system SHALL transfer database content from source to target using Unix pipe streaming to eliminate intermediate disk I/O and maximize transfer speed.

#### Scenario: Zero-disk database transfer
- **WHEN** the cloning script initiates database sync
- **THEN** pg_dump streams data directly to psql through a Unix pipe
- **AND** no intermediate files are written to disk
- **AND** the transfer occurs entirely in memory buffers

#### Scenario: Fast transfer for typical databases
- **WHEN** syncing a 500MB database
- **THEN** the transfer completes in under 20 seconds
- **AND** when syncing a 1GB database
- **THEN** the transfer completes in under 30 seconds

#### Scenario: Network-bound performance
- **WHEN** database sync is in progress
- **THEN** the bottleneck is network bandwidth (not disk I/O)
- **AND** throughput exceeds 50 MB/sec on typical connections

### Requirement: Database Connection String Extraction
The system SHALL extract PostgreSQL connection strings from Railway environment variables using the Railway CLI JSON output.

#### Scenario: Parse source database URL
- **WHEN** the script needs the production database URL
- **THEN** it executes railway variables with JSON output flag
- **AND** parses the DATABASE_URL using jq
- **AND** validates the URL contains all required components (host, port, database, credentials)

#### Scenario: Parse target database URL
- **WHEN** the script needs the staging database URL
- **THEN** it executes railway variables for the target environment
- **AND** extracts DATABASE_URL from JSON output
- **AND** confirms the URL points to a different database instance than source

#### Scenario: Handle missing database URLs
- **WHEN** DATABASE_URL is not present in environment variables
- **THEN** the system exits with a clear error message
- **AND** instructs the user to provision a database service
- **AND** provides the Railway CLI command to add a database

### Requirement: Safe Database Overwrite
The system SHALL safely replace existing content in the target database using pg_dump flags that prevent data corruption and handle existing objects.

#### Scenario: Clean slate restoration
- **WHEN** pg_dump executes with --clean and --if-exists flags
- **THEN** existing database objects are dropped before restoration
- **AND** the operation does not fail if objects do not exist
- **AND** the target database contains only source data after completion

#### Scenario: Ownership and privileges handling
- **WHEN** pg_dump executes with --no-owner and --no-privileges flags
- **THEN** object ownership is not transferred (uses target database owner)
- **AND** permissions are not copied from source
- **AND** the target database applies its own default permissions

#### Scenario: Plain SQL format for pipes
- **WHEN** pg_dump streams to psql
- **THEN** the format is plain SQL (not custom or compressed)
- **AND** the output is compatible with psql stdin
- **AND** the stream can be piped without intermediate processing

### Requirement: Database Sync Error Handling
The system SHALL detect and handle database synchronization failures with clear error messages and automatic rollback.

#### Scenario: Network interruption during transfer
- **WHEN** the network connection drops during pg_dump streaming
- **THEN** the pipe fails immediately
- **AND** the script detects the failure via exit code
- **AND** triggers environment rollback (deletes staging environment)
- **AND** logs the network error with retry instructions

#### Scenario: Source database unreachable
- **WHEN** pg_dump cannot connect to the source database
- **THEN** the operation fails within 10 seconds (connection timeout)
- **AND** the error message includes the database host and port
- **AND** suggests checking Railway service status

#### Scenario: Target database insufficient space
- **WHEN** the target database runs out of storage during restoration
- **THEN** psql exits with a disk space error
- **AND** the script captures the error and logs it
- **AND** suggests upgrading the Railway database plan

#### Scenario: Authentication failure
- **WHEN** database credentials are invalid or expired
- **THEN** the connection attempt fails immediately
- **AND** the error message indicates authentication failure
- **AND** instructs the user to verify Railway database provisioning

### Requirement: Atomic Database Operations
The system SHALL ensure database synchronization either completes fully or fails completely, with no partial state persisted.

#### Scenario: All-or-nothing transfer
- **WHEN** database sync begins
- **THEN** the operation runs within a transaction context
- **AND** if any error occurs, all changes are rolled back
- **AND** the target database remains in its pre-sync state on failure

#### Scenario: Pipe failure detection
- **WHEN** either pg_dump or psql exits with non-zero status
- **THEN** the Bash pipe fails immediately (set -o pipefail)
- **AND** the script detects the failure via $? check
- **AND** triggers cleanup and rollback procedures

### Requirement: Database Sync Progress Visibility
The system SHALL provide visibility into database synchronization progress through logging and status updates.

#### Scenario: Log sync start and completion
- **WHEN** database sync begins
- **THEN** the script emits a log message with timestamp
- **AND** logs the source and target database names (not full URLs)
- **AND** when sync completes, logs the duration

#### Scenario: Sanitize connection strings in logs
- **WHEN** any log message references a database URL
- **THEN** the password component is masked (replaced with ***)
- **AND** the username, host, and database name remain visible
- **AND** full connection strings are never written to log files

#### Scenario: Estimate transfer time
- **WHEN** database sync begins
- **THEN** the script optionally queries source database size
- **AND** provides an estimated completion time based on typical throughput
- **AND** updates the user with "Transfer may take X seconds"

### Requirement: Retry Logic for Transient Failures
The system SHALL automatically retry database synchronization operations when encountering transient network or connection errors.

#### Scenario: Retry on connection timeout
- **WHEN** database connection times out on first attempt
- **THEN** the system waits 5 seconds and retries
- **AND** retries up to 3 times with exponential backoff (5s, 10s, 20s)
- **AND** logs each retry attempt
- **AND** exits with failure after 3 failed attempts

#### Scenario: No retry on authentication errors
- **WHEN** database authentication fails
- **THEN** the system does not retry (permanent failure)
- **AND** exits immediately with authentication error message

#### Scenario: No retry on disk space errors
- **WHEN** target database reports insufficient space
- **THEN** the system does not retry (permanent failure)
- **AND** exits with disk space error message

### Requirement: Large Database Support
The system SHALL support database synchronization for databases up to 5GB with appropriate timeout and progress handling.

#### Scenario: Extended timeout for large databases
- **WHEN** syncing databases larger than 2GB
- **THEN** the script increases the pg_dump and psql statement timeout
- **AND** allows up to 10 minutes for transfer completion
- **AND** logs a warning about extended transfer time

#### Scenario: Chunked transfer for very large databases
- **WHEN** syncing databases larger than 5GB
- **THEN** the system recommends using Railway's native backup/restore
- **AND** provides instructions for manual large-database cloning
- **AND** optionally implements table-by-table streaming (future enhancement)

### Requirement: Database Schema Compatibility
The system SHALL verify that source and target databases use compatible PostgreSQL versions before initiating synchronization.

#### Scenario: PostgreSQL version check
- **WHEN** database sync begins
- **THEN** the script queries PostgreSQL version from source and target
- **AND** verifies major versions match (e.g., both are Postgres 15.x)
- **AND** emits a warning if minor versions differ
- **AND** fails if major versions are incompatible

#### Scenario: Extension compatibility
- **WHEN** source database uses PostgreSQL extensions
- **THEN** the script verifies target database has the same extensions installed
- **AND** logs any missing extensions
- **AND** provides instructions to install missing extensions via Railway CLI
