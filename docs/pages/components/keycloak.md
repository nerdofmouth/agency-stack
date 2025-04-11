---
layout: default
title: Keycloak - AgencyStack Documentation
---

# Keycloak

## Overview

Keycloak is an open-source Identity and Access Management (IAM) solution that provides Single Sign-On (SSO) capabilities for AgencyStack components. It serves as the central identity provider for all components marked with `sso: true` in the component registry.

**Key Features:**
- Single Sign-On (SSO) across all AgencyStack components
- Identity management with user registration and profile management
- Role-based access control (RBAC)
- Multi-factor authentication (MFA)
- Social login integration
- OpenID Connect (OIDC) and SAML support
- Multi-tenancy through isolated realms

## Technical Specifications

| Parameter | Value |
|-----------|-------|
| **Version** | Latest (Quarkus-based) |
| **Default URL** | https://yourdomain.com/admin |
| **Web Port** | 8080 (internal) |
| **Container Image** | quay.io/keycloak/keycloak:latest |
| **Data Directory** | /opt/agency_stack/keycloak/{DOMAIN}/ |
| **Log File** | /var/log/agency_stack/components/keycloak.log |

## Installation

### Prerequisites
- Docker and Docker Compose
- Traefik configured with Let's Encrypt
- Domain name properly configured in DNS
- PostgreSQL database (automatically installed as a dependency)

### Installation Commands

**Basic Installation:**
```bash
make install-keycloak DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com
```

**With Optional Parameters:**
```bash
make install-keycloak DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com CLIENT_ID=customclient --force
```

### Installation Options
- `--domain`: Domain name for Keycloak (required)
- `--admin-email`: Admin email for notifications (required)
- `--client-id`: Client ID for multi-tenancy (default: "default")
- `--verbose`: Enable verbose output
- `--force`: Force installation even if already installed
- `--with-deps`: Install dependencies automatically
- `--help`: Show help message and exit

## Configuration

### Default Configuration
- Admin user is created during installation
- Default realm for the client ID is created
- TLS termination is handled by Traefik
- Database is automatically configured with PostgreSQL

### Customization
- Custom themes can be placed in `/opt/agency_stack/keycloak/{DOMAIN}/themes`
- Import files can be placed in `/opt/agency_stack/keycloak/{DOMAIN}/imports`
- Environment variables can be modified in the docker-compose.yml file

## Component Integration

Keycloak is designed to integrate with all AgencyStack components that have `sso: true` in the component registry. Currently supported components include:

- **PeerTube**: Video streaming platform integration
- **Gitea**: Git repository management integration
- **Mattermost**: Team communication integration
- **WordPress**: Content management integration

### Integration Commands

To integrate a component with Keycloak:

```bash
# For PeerTube
make peertube-sso-configure DOMAIN=yourdomain.com

# For other components
make <component>-sso-configure DOMAIN=yourdomain.com
```

### Client Configuration Templates

Client configuration templates are stored in:
```
/opt/agency_stack/repo/scripts/components/keycloak/clients/
```

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Admin UI | 8080 (internal) | HTTPS | Keycloak administration interface |
| REST API | 8080 (internal) | HTTPS | OpenID Connect and administration API |
| Health | 8080 (internal) | HTTPS | Health check endpoint |

## Logs & Monitoring

### Log Files
- Installation logs: `/var/log/agency_stack/components/keycloak.log`
- Container logs: Access with `make keycloak-logs`
- Database logs: Access with `docker logs keycloak_postgres_<domain_underscore>`

### Health Monitoring
- Health endpoint: `https://yourdomain.com/health`
- Status check: `make keycloak-status`

## Troubleshooting

### Common Issues

1. **Container fails to start:**
   - Check PostgreSQL container is running
   - Verify container logs with `make keycloak-logs`
   - Ensure ports are not in use by other services

2. **Cannot access admin console:**
   - Verify Traefik is properly configured
   - Check DNS resolution for the domain
   - Ensure Keycloak container is running

3. **SSO integration issues:**
   - Verify client configuration in Keycloak
   - Check component's OAuth configuration
   - Validate OpenID configuration URL is accessible

### Recovery Procedures

If Keycloak fails or becomes corrupted:

```bash
# Restart Keycloak
make keycloak-restart

# Reinstall if necessary
make install-keycloak DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com --force
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make install-keycloak` | Install Keycloak |
| `make keycloak` | Alias for install-keycloak |
| `make keycloak-status` | Check status of Keycloak |
| `make keycloak-logs` | View Keycloak logs |
| `make keycloak-restart` | Restart Keycloak services |
| `make keycloak-test` | Test Keycloak functionality |

## Security Considerations

- Admin credentials are stored in `/opt/agency_stack/secrets/keycloak/{DOMAIN}/admin.env`
- Client secrets are stored in `/opt/agency_stack/secrets/keycloak/{DOMAIN}/{client}.env`
- All communications are encrypted with TLS
- Default configuration includes security headers for XSS protection
- Multi-tenant isolation with separate realms per client

## References

- [Official Keycloak Documentation](https://www.keycloak.org/documentation)
- [OpenID Connect Specification](https://openid.net/specs/openid-connect-core-1_0.html)
