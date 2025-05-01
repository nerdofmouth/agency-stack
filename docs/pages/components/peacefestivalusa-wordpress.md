# Peace Festival USA WordPress Implementation

## Overview

This document describes the WordPress implementation for the Peace Festival USA client, deployed using the AgencyStack multi-tenant architecture. The deployment follows the AgencyStack Charter v1.0.3 and TDD Protocol principles, ensuring repository integrity, idempotency, and proper testing.

## Installation

The Peace Festival USA WordPress implementation uses the generic client WordPress deployment framework, which provides:

- Docker-based containerization
- Multi-tenant isolation
- Standard directory structure
- Comprehensive testing
- Docker-in-Docker compatibility

### Prerequisites

- Docker and Docker Compose
- Access to the AgencyStack repository
- Proper DNS configuration for peacefestivalusa.nerdofmouth.com (for production deployment)

### Directory Structure

Following the AgencyStack Charter v1.0.3, all files are organized in the standard directory structure:

```
/opt/agency_stack/clients/peacefestivalusa/wordpress/
├── wp-content/              # WordPress content (themes, plugins, uploads)
├── mariadb-data/            # MariaDB database files
├── wp-config/               # WordPress custom configuration
│   └── wp-config-agency.php # AgencyStack-specific WordPress configuration
├── docker-compose.yml       # Docker Compose configuration
└── .env                     # Environment variables
```

In Docker-in-Docker development mode, the path is:

```
$HOME/.agencystack/clients/peacefestivalusa/wordpress/
```

## Installation Methods

### Standard Installation

```bash
# Install WordPress for Peace Festival USA
make peacefestivalusa-wordpress

# Or with the generic multi-tenant client approach
make client-wordpress CLIENT_ID=peacefestivalusa DOMAIN=peacefestivalusa.nerdofmouth.com WP_PORT=8082 MARIADB_PORT=33060
```

### Docker-in-Docker Development

```bash
# Install WordPress for Peace Festival USA in Docker-in-Docker
make peacefestivalusa-wordpress-did

# Or with the generic multi-tenant client approach
make client-wordpress-did CLIENT_ID=peacefestivalusa DOMAIN=peacefestivalusa.nerdofmouth.com WP_PORT=8082 MARIADB_PORT=33060
```

## Management Commands

```bash
# Check status
make peacefestivalusa-wordpress-status

# View logs
make peacefestivalusa-wordpress-logs

# Restart services
make peacefestivalusa-wordpress-restart

# Run tests
make peacefestivalusa-wordpress-test
```

## Testing

Following the AgencyStack TDD Protocol, comprehensive test suites have been implemented:

1. **Unit Tests**
   - Directory structure validation
   - Credentials file security
   - Configuration file validation

2. **Integration Tests**
   - Container status verification
   - Docker networking configuration
   - Port mapping validation

3. **System Tests**
   - WordPress HTTP response validation
   - Database connectivity
   - Volume mounting verification

Run the test suite with:

```bash
make peacefestivalusa-wordpress-test
```

## Architecture Details

### Docker Containers

- **WordPress Container**: `peacefestivalusa_wordpress`
  - Image: wordpress:6.1-php8.1-apache
  - Port: 8082 (mapped to 80)

- **MariaDB Container**: `peacefestivalusa_mariadb`
  - Image: mariadb:10.5
  - Port: 33060 (mapped to 3306)

### Networking

Docker networking is used to isolate the Peace Festival USA WordPress deployment with a dedicated network:

- Network name: `peacefestivalusa_network`
- Internal communication: WordPress container connects to the database container via internal Docker network
- External access: Port mapping provides access from outside the Docker network

### Security

- Database credentials are automatically generated and stored securely
- WordPress admin password is randomly generated
- All sensitive information is stored in `/opt/agency_stack/clients/peacefestivalusa/.secrets/`
- File permissions on sensitive files are restricted to 600

## Implementation Notes

This deployment of Peace Festival USA follows the generic multi-tenant WordPress framework, allowing for:

1. Consistency across all client deployments
2. Easy replication for new clients
3. Standardized testing and validation
4. Docker-in-Docker compatibility for development
5. Adherence to the AgencyStack Charter v1.0.3 principles

## Troubleshooting

### Common Issues

1. **Port Conflicts**: If ports 8082 or 33060 are already in use, modify the `WP_PORT` and `MARIADB_PORT` parameters.

2. **Docker-in-Docker Networking**: In Docker-in-Docker mode, networking can be complex. Use the container IP addresses directly if localhost access fails.

3. **WordPress Not Accessible**: Check logs with `make peacefestivalusa-wordpress-logs` to diagnose issues.

### Logs

Logs are stored in the following locations:

- Installation logs: `/var/log/agency_stack/components/peacefestivalusa_wordpress.log`
- Test logs: `/var/log/agency_stack/components/peacefestivalusa_wordpress_test.log`
- WordPress container logs: Access via `docker logs peacefestivalusa_wordpress`
- MariaDB container logs: Access via `docker logs peacefestivalusa_mariadb`
