# Subdomain Routing Specification

## ADDED Requirements

### Requirement: Automatic Domain Assignment
The system SHALL automatically assign unique domains to newly created staging environments using Railway's domain provisioning system.

#### Scenario: Railway-generated domain
- **WHEN** a staging environment is created
- **THEN** the system executes railway domain command for the target environment
- **AND** Railway generates a unique subdomain (e.g., staging-client-x-abc123.railway.app)
- **AND** the domain is immediately accessible via HTTPS

#### Scenario: Domain assignment logging
- **WHEN** domain assignment completes
- **THEN** the script emits the full staging URL in the success message
- **AND** provides a clickable link in terminal output
- **AND** logs the domain for audit purposes

#### Scenario: Domain assignment failure handling
- **WHEN** domain assignment fails (Railway API error)
- **THEN** the system logs the failure but does not roll back the environment
- **AND** instructs the user to manually assign a domain via Railway dashboard
- **AND** provides the Railway CLI command to retry domain assignment

### Requirement: Custom Domain Support
The system SHALL support optional custom domain assignment for staging environments when specified by the user.

#### Scenario: Custom subdomain specification
- **WHEN** the user provides a custom domain via --domain flag
- **THEN** the script configures Railway to use the specified custom domain
- **AND** verifies DNS records are properly configured
- **AND** emits instructions if DNS records are missing

#### Scenario: Custom domain validation
- **WHEN** a custom domain is specified
- **THEN** the system validates the domain format (valid FQDN)
- **AND** checks the domain is not already in use by another service
- **AND** provides clear error messages for invalid domains

#### Scenario: Fallback to Railway domain
- **WHEN** custom domain provisioning fails
- **THEN** the system falls back to Railway-generated domain
- **AND** logs the custom domain failure reason
- **AND** still completes the clone operation successfully

### Requirement: Domain Accessibility Verification
The system SHALL verify that assigned domains are accessible and respond to HTTP requests before marking the operation as complete.

#### Scenario: HTTP health check
- **WHEN** domain assignment completes
- **THEN** the system performs an HTTP GET request to the domain root
- **AND** waits up to 60 seconds for a successful response (200, 301, 302)
- **AND** logs the response status code

#### Scenario: Service startup delay handling
- **WHEN** the domain is assigned but service is still starting
- **THEN** the system retries health check every 10 seconds for up to 2 minutes
- **AND** provides progress updates ("Waiting for service to start...")
- **AND** considers the operation successful even if health check times out (non-blocking)

#### Scenario: SSL certificate provisioning
- **WHEN** a new domain is assigned by Railway
- **THEN** Railway automatically provisions an SSL certificate
- **AND** the domain is accessible via HTTPS within 2 minutes
- **AND** HTTP requests automatically redirect to HTTPS

### Requirement: Domain Naming Conventions
The system SHALL enforce domain naming conventions to ensure consistency and prevent conflicts across staging environments.

#### Scenario: Staging environment prefix
- **WHEN** generating Railway domain names
- **THEN** the domain includes the environment name (e.g., staging-client-x)
- **AND** follows the pattern: [env-name]-[project-id].railway.app
- **AND** is unique across the Railway project

#### Scenario: Client identification in domains
- **WHEN** creating staging for specific clients
- **THEN** the environment name includes client identifier
- **AND** follows pattern: staging-[client-name] or staging-[client-id]
- **AND** uses lowercase and hyphens (no underscores or special characters)

#### Scenario: Collision avoidance
- **WHEN** the desired domain name is already taken
- **THEN** Railway automatically appends a unique suffix
- **AND** the system logs the actual assigned domain
- **AND** no manual intervention is required

### Requirement: Multi-Service Domain Routing
The system SHALL handle domain routing for staging environments that contain multiple services (web, api, admin, etc.).

#### Scenario: Primary service domain
- **WHEN** a staging environment has multiple services
- **THEN** the primary web service receives the main domain assignment
- **AND** the domain routes to the service with the web role or port 80/443

#### Scenario: Service-specific subdomains
- **WHEN** multiple services need external access
- **THEN** the system optionally assigns service-specific domains
- **AND** follows pattern: [service-name]-[env-name].railway.app
- **AND** each service has an independent domain

#### Scenario: Internal service routing
- **WHEN** some services are internal-only (database, cache)
- **THEN** no external domain is assigned to those services
- **AND** services communicate via Railway's internal networking
- **AND** only web-facing services receive public domains

### Requirement: Domain Management and Cleanup
The system SHALL provide mechanisms to manage and clean up domains when staging environments are deleted.

#### Scenario: Automatic domain deletion
- **WHEN** a staging environment is deleted
- **THEN** Railway automatically removes associated domains
- **AND** the domain becomes available for reuse
- **AND** SSL certificates are revoked

#### Scenario: Domain listing for audit
- **WHEN** the user requests a list of active staging environments
- **THEN** the system lists all environments with their assigned domains
- **AND** indicates which domains are Railway-managed vs custom
- **AND** shows domain creation timestamp

#### Scenario: Orphaned domain detection
- **WHEN** domain cleanup fails due to Railway API error
- **THEN** the system logs the orphaned domain
- **AND** provides a command to manually remove the domain
- **AND** includes the domain in a cleanup report

### Requirement: Domain Configuration for WordPress
The system SHALL configure WordPress-specific settings to ensure proper operation with the assigned staging domain.

#### Scenario: WordPress site URL configuration
- **WHEN** a staging environment is created with a new domain
- **THEN** the system updates WordPress site URL (WP_HOME and WP_SITEURL)
- **AND** sets environment variables in Railway for the new domain
- **AND** ensures WordPress redirects to the correct staging URL

#### Scenario: Search and replace for URLs
- **WHEN** production database is cloned to staging
- **THEN** the system optionally runs wp search-replace command
- **AND** updates all production URLs to staging URLs in database
- **AND** handles serialized PHP data correctly

#### Scenario: Multisite domain handling
- **WHEN** WordPress is configured as a multisite installation
- **THEN** the system updates the wp_blogs table with new domains
- **AND** configures domain mapping for each subsite
- **AND** logs any multisite-specific configuration changes

### Requirement: Domain Security and Access Control
The system SHALL provide security controls for staging domains to prevent unauthorized access to client preview environments.

#### Scenario: HTTP Basic Authentication
- **WHEN** staging environment requires access restriction
- **THEN** the system configures HTTP basic auth via environment variables
- **AND** generates a random username and password
- **AND** logs credentials securely (not in plain text logs)

#### Scenario: IP whitelisting support
- **WHEN** stricter access control is required
- **THEN** the system supports Railway's IP allow-list configuration
- **AND** restricts access to specified IP ranges
- **AND** provides clear error messages for blocked requests

#### Scenario: Staging environment labeling
- **WHEN** a staging domain is accessed
- **THEN** the site displays a visible staging banner or indicator
- **AND** prevents accidental production operations (e.g., payment processing)
- **AND** clarifies to users they are on a preview environment

### Requirement: Domain Performance and Caching
The system SHALL configure domain routing with appropriate caching and performance settings for staging environments.

#### Scenario: CDN configuration
- **WHEN** Railway provides CDN services
- **THEN** staging domains automatically use Railway's CDN
- **AND** static assets are cached at edge locations
- **AND** cache headers are respected

#### Scenario: Cache invalidation on updates
- **WHEN** staging environment is updated with new code or data
- **THEN** the system optionally triggers cache invalidation
- **AND** ensures users see latest changes immediately
- **AND** logs cache invalidation status

#### Scenario: DNS propagation monitoring
- **WHEN** a custom domain is assigned
- **THEN** the system monitors DNS propagation status
- **AND** provides estimated time for full propagation
- **AND** logs when domain is globally resolvable
