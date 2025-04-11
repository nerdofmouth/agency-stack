# Keycloak

## Overview
Keycloak is an open-source Identity and Access Management solution that provides Single Sign-On (SSO) capabilities for AgencyStack applications. It serves as the central authentication and authorization system, enabling secure user management and access control across all integrated components.

## Installation

### Prerequisites
- Docker and Docker Compose
- Traefik (for HTTPS and routing)
- PostgreSQL (for persistent storage)
- Domain name with proper DNS configuration

### Installation Process
The installation is handled by the `install_keycloak.sh` script, which can be executed using:

```bash
make keycloak DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com
```

## Configuration

### Default Configuration
- Automatically creates a secure Docker network
- Sets up PostgreSQL database for persistent storage
- Configures Traefik integration for HTTPS
- Creates default "agency" realm with admin user
- Generates secure passwords and stores them in `/opt/agency_stack/secrets/keycloak/`

### Customization
- Configuration files are stored in `/opt/agency_stack/keycloak/<domain>/`
- Realm configuration: `/opt/agency_stack/keycloak/<domain>/imports/agency-realm.json`
- Docker Compose file: `/opt/agency_stack/keycloak/<domain>/docker-compose.yml`

## SSO Integration

### Integration Process
Components marked with `sso: true` in the component registry must integrate with Keycloak. The integration process is standardized using the `/scripts/utils/keycloak_integration.sh` utility script:

```bash
source /home/revelationx/CascadeProjects/foss-server-stack/scripts/utils/keycloak_integration.sh
integrate_with_keycloak "yourdomain.com" "component-name" "framework" "https://component.yourdomain.com"
```

### Integration Requirements
For a component to be properly integrated with Keycloak SSO:

1. The component installation script must:
   - Check for Keycloak availability using `keycloak_is_available`
   - Create a realm or use an existing one with `keycloak_create_realm`
   - Register a client with `keycloak_register_client`
   - Store credentials securely with `store_keycloak_credentials`
   - Generate integration code with `generate_keycloak_integration_code`

2. The component must support one of these authentication flows:
   - OpenID Connect (OIDC) - Preferred
   - SAML 2.0

3. The component registry entry must include:
   - `"sso": true` - Indicating SSO capability
   - `"sso_configured": true` - Only after live integration is tested

### Supported Frameworks
The integration utility provides templates for:
- Node.js (Express)
- Python (Flask)
- Docker (Environment variables)

Custom frameworks can be integrated by implementing the OpenID Connect or SAML protocols using the credentials stored in `/opt/agency_stack/keycloak/clients/`.

## Multi-Tenancy Support

Keycloak supports multi-tenant deployments by:
- Creating separate realms for each tenant
- Isolating users and configurations between tenants
- Supporting tenant-specific client configurations

For components with `multi_tenant: true`, the integration will create tenant-isolated realms automatically.

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Admin Console | 8080 | HTTP (internal) | Administration interface (proxied via Traefik) |
| Auth API | 8080 | HTTP (internal) | Authentication and token endpoints (proxied via Traefik) |

External access is provided through Traefik on standard HTTPS ports (443) at:
- Admin Console: `https://<domain>/auth/admin`
- Auth Endpoints: `https://<domain>/auth/realms/`

## Logs & Monitoring

### Log Files
- Installation logs: `/var/log/agency_stack/components/keycloak.log`
- Integration logs: `/var/log/agency_stack/components/keycloak_integration.log`
- Container logs: Access via `make keycloak-logs`

### Monitoring
- Health check endpoint: `https://<domain>/auth/health`
- Metrics endpoint: `https://<domain>/auth/metrics` (when enabled)
- Events are logged to the database and can be viewed in the Admin Console

## Security

### Best Practices
- Admin password is auto-generated and stored securely
- HTTPS is enforced for all communications
- Sensitive data is stored in the `/opt/agency_stack/secrets/` directory with restricted permissions
- Client secrets are automatically rotated when using the `--force` flag during reinstallation

### Password Policies
- Default password policy requires minimum 8 characters with at least:
  - 1 uppercase letter
  - 1 lowercase letter
  - 1 number
  - 1 special character

## Troubleshooting

### Common Issues
- **Cannot access admin console**: Check Traefik logs and ensure proper DNS configuration
- **Integration failures**: Verify Keycloak is running with `make keycloak-status`
- **Client registration errors**: Check permissions and ensure admin credentials are correct
- **Connection refused**: Ensure Docker network is properly configured

### Debugging
- Increase log verbosity with `make keycloak VERBOSE=true`
- View detailed logs with `make keycloak-logs`
- Check container status with `docker ps | grep keycloak`

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make keycloak` | Install Keycloak |
| `make keycloak-status` | Check status of Keycloak |
| `make keycloak-logs` | View Keycloak logs |
| `make keycloak-restart` | Restart Keycloak services |
