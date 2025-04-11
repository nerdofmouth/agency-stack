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

## 🔐 External OAuth via Keycloak IDPs

AgencyStack supports social login via external OAuth providers (Google, GitHub, Apple, LinkedIn, Microsoft) while maintaining sovereignty by integrating these through Keycloak as the centralized identity provider. This architecture ensures all authentication flows and user data remain within your control while offering the convenience of social login.

### Supported Providers

| Provider | Feature Flag | Required Environment Variables |
|----------|--------------|--------------------------------|
| Google   | `--enable-oauth-google` | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| GitHub   | `--enable-oauth-github` | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` |
| Apple    | `--enable-oauth-apple`  | `APPLE_CLIENT_ID`, `APPLE_CLIENT_SECRET`   |
| LinkedIn | `--enable-oauth-linkedin` | `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET` |
| Microsoft | `--enable-oauth-microsoft` | `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET` |

### Installation with OAuth Providers

```bash
# Install Keycloak with Google OAuth support
export GOOGLE_CLIENT_ID="your-client-id"
export GOOGLE_CLIENT_SECRET="your-client-secret"
make install-keycloak DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com ENABLE_OAUTH_GOOGLE=true

# Install with multiple providers
make install-keycloak DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com \
  ENABLE_OAUTH_GOOGLE=true \
  ENABLE_OAUTH_GITHUB=true \
  ENABLE_OAUTH_LINKEDIN=true
```

### Obtaining OAuth Credentials

To use external OAuth providers, you'll need to obtain credentials from each provider:

#### Google
1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project or select an existing one
3. Navigate to "APIs & Services" > "Credentials"
4. Click "Create Credentials" > "OAuth client ID"
5. Set authorized redirect URI to: `https://your-domain.com/auth/realms/agency/broker/google/endpoint`

#### GitHub
1. Go to your [GitHub Settings](https://github.com/settings/developers)
2. Navigate to "Developer settings" > "OAuth Apps"
3. Click "New OAuth App"
4. Set authorization callback URL to: `https://your-domain.com/auth/realms/agency/broker/github/endpoint`

#### Apple
1. Go to the [Apple Developer Portal](https://developer.apple.com/)
2. Navigate to "Certificates, IDs & Profiles"
3. Register a new "Services ID" with "Sign In with Apple" capability
4. Configure the return URL as: `https://your-domain.com/auth/realms/agency/broker/apple/endpoint`

#### LinkedIn
1. Go to the [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. Click "Create App" to register a new application
3. Under "Auth" tab, add the OAuth 2.0 redirect URL: `https://your-domain.com/auth/realms/agency/broker/linkedin/endpoint`
4. Request the necessary scopes: `r_liteprofile` and `r_emailaddress`

#### Microsoft/Azure AD
1. Go to the [Azure Portal](https://portal.azure.com/)
2. Navigate to "Azure Active Directory" > "App registrations"
3. Click "New registration"
4. Add redirect URI: `https://your-domain.com/auth/realms/agency/broker/microsoft/endpoint`
5. Under "Certificates & secrets", create a new client secret
6. Under "API permissions", add permissions for "Microsoft Graph" (email, profile, user.read)

### OAuth IdP Management

AgencyStack provides dedicated targets to manage and test OAuth identity providers:

| Target | Description |
|--------|-------------|
| `make keycloak-idp-status` | Check status of configured OAuth Identity Providers |
| `make keycloak-idp-test` | Run comprehensive tests on OAuth Identity Provider configuration |
| `make keycloak-idp-mock` | Start a mock OAuth server for testing without external dependencies |

### OAuth Identity Provider Security

When configuring OAuth Identity Providers, the following security considerations are automatically applied:

- **Secure Credential Storage**: All OAuth client secrets are stored in restricted files (`/opt/agency_stack/secrets/keycloak/{DOMAIN}/{provider}_oauth.env`) with 600 permissions
- **Signature Validation**: Token signatures are validated to prevent forgery
- **Token Storage Policy**: OAuth tokens from external providers are not stored in Keycloak by default
- **Scope Limitations**: Only essential scopes are requested (e.g., email, profile)
- **Mappers**: Email and username mappers are configured automatically to ensure proper user attribution

### Multi-Tenant OAuth Configuration

For multi-tenant setups, OAuth providers can be configured per client:

```bash
# Configure OAuth for specific client/tenant
make install-keycloak DOMAIN=your-domain.com \
  CLIENT_ID=tenant1 \
  ENABLE_OAUTH_GOOGLE=true

# Check status for specific client/tenant
make keycloak-idp-status DOMAIN=your-domain.com --client-id tenant1
```

Each client gets isolated OAuth configurations in their own realm.

## Authentication Flow

1. User selects "Sign in with Google/GitHub/Apple/LinkedIn/Microsoft" on a Keycloak login screen
2. User is redirected to the external provider (Google, GitHub, Apple, LinkedIn, Microsoft)
3. After successful authentication, the user is redirected back to Keycloak
4. Keycloak creates or updates the user account based on information from the provider
5. User is authenticated in AgencyStack with proper roles and permissions

### Security Benefits

- OAuth credentials are managed centrally, not in individual applications
- User identity remains under AgencyStack control
- All security policies, role mappings, and access controls are managed in Keycloak
- Authentication sessions are unified through Keycloak
- Applications never get direct access to external provider tokens

### Important Notes

- Applications must NOT configure their own direct OAuth integrations
- All OAuth flows MUST go through Keycloak as the identity broker
- Roles from external providers must be explicitly mapped in Keycloak

## References

- [Official Keycloak Documentation](https://www.keycloak.org/documentation)
- [OpenID Connect Specification](https://openid.net/specs/openid-connect-core-1_0.html)
