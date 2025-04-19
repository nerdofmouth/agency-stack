# TLS Configuration for AgencyStack

This document outlines how Transport Layer Security (TLS) is implemented across the AgencyStack components, ensuring encrypted communication and secure access to all services.

## Overview

AgencyStack uses Traefik as a reverse proxy with Let's Encrypt integration to provide automatic TLS certificate issuance and renewal. All components are configured to enforce HTTPS by default, with HTTP-to-HTTPS redirection enabled.

## Configuration Components

### 1. Traefik TLS Configuration

Traefik is set up with the following TLS features:
- Let's Encrypt certificate resolver for automatic certificate issuance
- Certificate renewal management
- HTTP to HTTPS redirection middleware
- TLS version enforcement (TLS 1.2+)

### 2. HTTPS Redirect Enforcement

All components use Traefik labels to enforce HTTPS:

```yaml
- "traefik.http.middlewares.redirect_https.redirectscheme.scheme=https"
- "traefik.http.middlewares.redirect_https.redirectscheme.permanent=true"
- "traefik.http.routers.[service]_http.middlewares=redirect_https"
```

### 3. Certificate Management

Certificates are automatically managed by Let's Encrypt through Traefik:
- Certificates are stored in `/opt/agency_stack/traefik/certificates/`
- Renewal is automatic and handled by Traefik
- Wildcard certificates require DNS challenge setup

## Installation and Setup

### Basic TLS Setup

```bash
# Install Traefik with TLS configuration
make traefik-ssl DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com

# Verify TLS configuration
make tls-verify DOMAIN=yourdomain.com
```

### Enabling TLS for Components

When installing components with TLS support:

```bash
# Install component with TLS enabled (example)
make wordpress DOMAIN=yourdomain.com --enforce-https

# For dashboard with Keycloak SSO integration
make dashboard DOMAIN=yourdomain.com --enable-keycloak --enforce-https
```

## Validation and Troubleshooting

### Verifying TLS Configuration

```bash
# Verify TLS status for all components
make tls-verify DOMAIN=yourdomain.com

# Check specific components (aliases to tls-verify)
make tls-status DOMAIN=yourdomain.com
```

### Common Issues and Solutions

1. **Certificate Issuance Failures**:
   - Ensure port 80 and 443 are open on your firewall
   - Check Let's Encrypt rate limits
   - Verify domain DNS configuration

2. **HTTP to HTTPS Redirect Not Working**:
   - Ensure Traefik middleware is properly configured
   - Check that component is using the redirect middleware

3. **Certificate Renewal Problems**:
   - Verify that Traefik can access Let's Encrypt servers
   - Check certificate expiration with `make tls-verify DOMAIN=yourdomain.com VERBOSE=true`

## Security Considerations

- All traffic is encrypted with TLS 1.2 or higher
- HTTP Strict Transport Security (HSTS) is enabled by default
- Weak cipher suites are disabled
- Regular TLS verification is recommended as part of maintenance

## Related Documentation

- [Component Port Reference](ports.md)
- [Keycloak SSO Integration](../components/keycloak.md)
- [Dashboard Configuration](../components/dashboard.md)
