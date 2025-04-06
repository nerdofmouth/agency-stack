---
layout: default
title: Keycloak - AgencyStack Documentation
---

# Keycloak

## Overview

Keycloak provides comprehensive identity and access management for AgencyStack, enabling centralized authentication, single sign-on (SSO), and fine-grained authorization across all components. It forms the security foundation for the entire stack while maintaining sovereignty and control.

## Features

- **Single Sign-On (SSO)**: Centralized login for all AgencyStack components
- **Identity Brokering**: Connect to external identity providers (social, enterprise)
- **Multi-Factor Authentication**: Enhanced security with TOTP, WebAuthn, etc.
- **User Federation**: Connect to LDAP, Active Directory, or custom user databases
- **Client Adapters**: Pre-configured integration with all AgencyStack components
- **Fine-Grained Authorization**: Role-based access control (RBAC)
- **Admin Console**: User-friendly interface for identity management
- **REST API**: Programmatic access to all functionality
- **Audit Logging**: Track all authentication and authorization events

## Prerequisites

- Docker and Docker Compose
- PostgreSQL database
- Traefik for routing and TLS termination

## Installation

Install Keycloak using the Makefile:

```bash
make keycloak
```

Options:

- `--domain=<domain>`: Domain name for the deployment
- `--admin-email=<email>`: Admin user email
- `--admin-password=<password>`: Initial admin password
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--with-deps`: Install dependencies (PostgreSQL)
- `--force`: Override existing installation

## Configuration

Keycloak configuration is stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/keycloak/config/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `KEYCLOAK_ADMIN` | Admin username | Derived from `ADMIN_EMAIL` |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin password | From installation |
| `KEYCLOAK_DB_HOST` | Database host | `postgres` |
| `KEYCLOAK_DB_PORT` | Database port | `5432` |
| `KEYCLOAK_DB_NAME` | Database name | `keycloak` |
| `KEYCLOAK_DB_USER` | Database username | `keycloak` |
| `KEYCLOAK_DB_PASSWORD` | Database password | Auto-generated |
| `KEYCLOAK_HTTPS_PORT` | HTTPS port | `8443` |
| `KEYCLOAK_HTTP_PORT` | HTTP port (redirect only) | `8080` |
| `PROXY_ADDRESS_FORWARDING` | Enable proxy support | `true` |

## Usage

### Management Commands

```bash
# Check status
make keycloak-status

# View logs
make keycloak-logs

# Restart service
make keycloak-restart
```

### Web Interface

The Keycloak admin console is accessible at:

```
https://auth.yourdomain.com/admin/
```

Default realm: `agency_stack`

### Initial Setup

1. Log in to the admin console with the credentials provided during installation
2. Navigate to the `agency_stack` realm
3. Configure required components:
   - Client applications
   - Identity providers
   - Authentication flows
   - User attributes
   - Role mappings

## Security

Keycloak is configured with the following security measures:

- TLS encryption for all communications
- Brute-force protection
- Session timeout controls
- Password policies
- IP filtering options
- Audit logging of all security events

## Monitoring

All Keycloak operations are logged to:

```
/var/log/agency_stack/components/keycloak.log
```

Metrics are exposed on the `/metrics` endpoint for Prometheus integration.

## Troubleshooting

### Common Issues

1. **Login failures**:
   - Check user credentials and account status
   - Verify realm settings and authentication flows
   - Check browser cookies and local storage

2. **Client application connection issues**:
   - Verify client registration and credentials
   - Check redirect URIs configuration
   - Validate client adapter settings

3. **Database connection errors**:
   - Verify PostgreSQL service is running
   - Check database credentials and connectivity
   - Ensure database schema exists and is up to date

### Logs

For detailed logs:

```bash
tail -f /var/log/agency_stack/components/keycloak.log
```

## Integration with Other Components

Keycloak is pre-integrated with all AgencyStack components:

1. **Web Applications**: WordPress, Ghost, PeerTube, etc.
2. **Business Tools**: ERPNext, KillBill, etc.
3. **Infrastructure**: Portainer, Grafana, Traefik
4. **AI Components**: AI Dashboard, LangChain UI

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/keycloak/config/standalone.xml
```

Custom themes can be added to:

```
/opt/agency_stack/clients/${CLIENT_ID}/keycloak/themes/
```

## Client Integration Example

For custom applications, here's a basic OpenID Connect integration example:

```javascript
const config = {
  realm: 'agency_stack',
  url: 'https://auth.yourdomain.com/auth',
  clientId: 'your-client-id',
  redirectUri: 'https://app.yourdomain.com/callback'
};

const keycloak = new Keycloak(config);

keycloak.init({ onLoad: 'login-required' })
  .then(authenticated => {
    if (authenticated) {
      // User is authenticated, store the token
      localStorage.setItem('token', keycloak.token);
      
      // Make authenticated requests
      fetch('https://api.yourdomain.com/data', {
        headers: {
          'Authorization': 'Bearer ' + keycloak.token
        }
      });
    }
  })
  .catch(error => {
    console.error('Authentication failed:', error);
  });
```

## Multi-tenancy Configuration

In multi-tenant environments, each client can have:

1. **Dedicated Realm**: Isolated authentication domain
2. **Custom Theme**: Branded login experience
3. **Separate User Base**: No user data sharing between clients
4. **Client-specific Policies**: Different security requirements per client
