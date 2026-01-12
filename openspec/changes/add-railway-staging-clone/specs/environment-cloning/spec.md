# Environment Cloning Specification

## ADDED Requirements

### Requirement: Railway Environment Duplication
The system SHALL create isolated Railway environments by duplicating an existing source environment, preserving all service configurations, environment variables, and Docker image references.

#### Scenario: Clone production to staging
- **WHEN** a user invokes the cloning script with a unique environment name
- **THEN** Railway creates a new environment with identical service definitions
- **AND** all environment variables are copied from the source environment
- **AND** Docker images and build configurations are preserved

#### Scenario: Prevent duplicate environment names
- **WHEN** a user attempts to create an environment with an existing name
- **THEN** the system rejects the request with a clear error message
- **AND** suggests alternative unique names (e.g., appending timestamp)

#### Scenario: Rollback on partial failure
- **WHEN** environment creation succeeds but subsequent steps fail
- **THEN** the system deletes the newly created environment
- **AND** exits with non-zero status code
- **AND** logs the failure reason

### Requirement: Environment Configuration Validation
The system SHALL validate that cloned environments have identical configurations to the source environment before marking the operation as successful.

#### Scenario: Verify environment variable count
- **WHEN** environment duplication completes
- **THEN** the system counts environment variables in both source and target
- **AND** emits a warning if counts do not match
- **AND** logs any missing or extra variables

#### Scenario: Verify service definitions
- **WHEN** environment duplication completes
- **THEN** the system confirms all services from source exist in target
- **AND** each service points to the same Docker image or repository

### Requirement: Environment Naming Conventions
The system SHALL enforce naming conventions for cloned environments to ensure consistency and prevent collisions.

#### Scenario: Valid environment name format
- **WHEN** a user provides an environment name
- **THEN** the system validates the name uses lowercase alphanumeric characters and hyphens
- **AND** the name starts with a letter
- **AND** the name is between 3 and 50 characters long

#### Scenario: Auto-generate unique names on collision
- **WHEN** a requested environment name already exists
- **THEN** the system suggests alternative names with timestamp suffix
- **AND** provides the option to auto-generate a unique name

### Requirement: Environment Isolation
The system SHALL ensure that cloned environments operate independently without affecting the source environment or other clones.

#### Scenario: Independent resource allocation
- **WHEN** a staging environment is created
- **THEN** Railway allocates separate compute resources
- **AND** the staging environment has its own database instance
- **AND** changes to staging do not affect production

#### Scenario: Separate domain assignments
- **WHEN** a staging environment is created
- **THEN** Railway assigns a unique domain (e.g., staging-client-x.railway.app)
- **AND** the domain is independent from production domains

### Requirement: Fast Environment Creation
The system SHALL complete environment duplication in under 5 seconds for typical WordPress service configurations.

#### Scenario: Rapid environment provisioning
- **WHEN** the Railway CLI executes environment duplication
- **THEN** the operation completes in under 5 seconds
- **AND** all services are in a ready state
- **AND** environment variables are immediately accessible

#### Scenario: Performance measurement
- **WHEN** the cloning script executes
- **THEN** the system logs the start and end time of environment creation
- **AND** calculates the duration
- **AND** emits a warning if duration exceeds 10 seconds

### Requirement: Error Handling and Recovery
The system SHALL provide clear error messages and recovery options when environment cloning fails.

#### Scenario: Railway API authentication failure
- **WHEN** the Railway CLI lacks valid authentication credentials
- **THEN** the system exits immediately with an error message
- **AND** instructs the user to set the RAILWAY_TOKEN environment variable
- **AND** provides a link to Railway token generation documentation

#### Scenario: Network connectivity failure
- **WHEN** the Railway API is unreachable
- **THEN** the system retries the operation up to 3 times with exponential backoff
- **AND** logs each retry attempt
- **AND** exits with a network error message if all retries fail

#### Scenario: Source environment not found
- **WHEN** the specified source environment does not exist
- **THEN** the system lists available environments
- **AND** exits with an error message indicating the correct environment names
