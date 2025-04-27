# Traefik-Keycloak SSO Integration

This component integrates Traefik with Keycloak SSO via OAuth2 Proxy to provide secure authentication for the Traefik dashboard.

## Overview

The integration combines three main components:
- **Traefik**: Modern reverse proxy and load balancer
- **Keycloak**: Enterprise-grade identity and access management
- **OAuth2 Proxy**: Authentication middleware for enforcing Keycloak authentication

## Installation

### Prerequisites
- Docker and Docker Compose
- A working AgencyStack environment

### Standard Installation
```bash
# Install with default settings
make traefik-keycloak-sso

# Custom installation
make traefik-keycloak-sso CLIENT_ID=myagency DOMAIN=example.com
```

## Configuration

The component is configured through files in:
`/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/`

### Key Files
- `config/traefik/traefik.yml`: Main Traefik configuration
- `config/traefik/dynamic/oauth2.yml`: OAuth2 middleware configuration
- `docker-compose.yml`: Container orchestration

## Authentication Details

### Traefik Dashboard
- URL: http://localhost:8090/dashboard/
- Authentication: Keycloak SSO

### Keycloak Admin Console
- URL: http://localhost:8091/auth/admin/
- Default Credentials: `admin` / `admin`

## Verification

```bash
# Run verification script
/opt/agency_stack/clients/default/traefik-keycloak/scripts/verify_integration.sh
```

## Logs

```bash
# View Traefik logs
docker logs traefik_default

# View Keycloak logs
docker logs keycloak_default

# View OAuth2 Proxy logs
docker logs oauth2_proxy_default
```

## Restart and Management

```bash
# Restart all services
cd /opt/agency_stack/clients/default/traefik-keycloak && docker-compose restart

# Stop all services
cd /opt/agency_stack/clients/default/traefik-keycloak && docker-compose down

# Start all services
cd /opt/agency_stack/clients/default/traefik-keycloak && docker-compose up -d
```

## Troubleshooting

### Authentication Failures
1. Verify Keycloak is running and accessible
2. Check if the client is properly configured in Keycloak:
   ```bash
   /opt/agency_stack/clients/default/traefik-keycloak/scripts/setup_keycloak.sh
   ```
3. Check OAuth2 Proxy logs for specific errors:
   ```bash
   docker logs oauth2_proxy_default
   ```

### Network Issues
1. Verify the Docker network exists and all containers are connected:
   ```bash
   docker network inspect traefik-net-default
   ```

## Security Considerations

- The default Keycloak admin credentials should be changed in production environments
- TLS encryption should be enabled for production deployments
- Regular security audits should be conducted

## Repository Integrity

This component strictly adheres to the AgencyStack Repository Integrity Policy:

- **Source-Controlled Configuration**: All configuration templates are defined in the repository at `/scripts/components/traefik-keycloak/`
- **Idempotent Installation**: The installation process can be run multiple times without side effects
- **No Direct VM Modifications**: All changes are applied through repository-defined scripts
- **Documented Behavior**: All component behavior is documented in human-readable formats
- **Repeatable Deployments**: Installation can be reproduced consistently across environments
- **Multi-Tenant Awareness**: The component supports isolation between clients via `CLIENT_ID`

The installation script validates it's running from the repository context before making any changes, ensuring all modifications are properly tracked and versioned.

## Lessons Learned

During the development of this integration, we encountered several challenges that led to improvements in our approach:

1. **OAuth2 Configuration Complexity**: OAuth2 Proxy requires careful configuration of URLs to work properly with Keycloak. We found that explicit configuration of all endpoints (login, redeem, profile, validate) is more reliable than relying on discovery.

2. **Container Naming Conflicts**: When redeploying services, container name conflicts can occur. Our installation now properly cleans up existing containers before creating new ones.

3. **Keycloak Realm Management**: While multi-realm setups are possible, using the master realm for simple deployments proved more reliable during initial setup. Future versions will implement proper realm isolation.

4. **Container Startup Coordination**: We found that OAuth2 proxy needs Keycloak to be fully initialized before it can properly discover OIDC endpoints. Our installation now implements a staged startup approach with readiness checks.

5. **Port Binding Conflicts**: Standard HTTP/HTTPS ports (80/443) may be in use by other services. We've incorporated port configuration validation and remediation to handle these cases gracefully.

These lessons have been incorporated into the current implementation to ensure smooth deployments for all users.
