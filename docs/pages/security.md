# AgencyStack Security Guide

This document outlines security best practices, features, and configuration options for your AgencyStack installation. Following these guidelines will help ensure your infrastructure remains secure and protected from common threats.

## Security Architecture

AgencyStack is designed with a security-first approach using multiple layers of protection:

1. **Network Security**: Isolated Docker networks with clear segmentation between frontend, backend, and database layers
2. **Authentication & Authorization**: Centralized identity management with Keycloak SSO
3. **Data Encryption**: TLS for all traffic, encrypted backups, and at-rest encryption for sensitive data
4. **Access Control**: Role-based access control with principle of least privilege
5. **Security Headers**: Strict security headers enforced through Traefik middleware
6. **Secrets Management**: Centralized secrets management with proper file permissions
7. **Multi-tenancy**: Full isolation between client environments

## Network Security

### Docker Network Isolation

Each client in AgencyStack has four dedicated networks:

- **Frontend Network**: For external-facing services (Traefik routing, web applications)
- **Backend Network**: For internal services communication (APIs, message queues)
- **Database Network**: Exclusively for database connections, isolated from the internet
- **Client Network**: For client-specific integrations

This isolation ensures that even if one service is compromised, the attack surface remains limited.

### Port Exposure Management

AgencyStack minimizes exposed ports by default:

- Only HTTP/HTTPS ports (80/443) are exposed to the internet
- Administrative interfaces are only accessible through Traefik with authentication
- Internal services communicate over private Docker networks

To check for port exposure, run:

```bash
sudo make security-audit
```

## Authentication & Authorization

### Keycloak Single Sign-On

All AgencyStack services use Keycloak for centralized authentication:

- OIDC/OAuth2 integration with all supported services
- Multi-factor authentication support
- Centralized role management
- Session management with proper timeouts

### Default Roles

For each client realm, AgencyStack creates three standard roles:

1. **realm_admin**: Full administrative access to the realm
2. **editor**: Can edit content but not manage users/roles
3. **viewer**: Read-only access to content

To set up roles for a client:

```bash
sudo scripts/keycloak/setup_roles.sh <client_id>
```

## TLS & Data Encryption

### TLS Configuration

AgencyStack enforces secure TLS settings through Traefik:

- Minimum TLS version: TLS 1.2 (TLS 1.3 preferred)
- Strong cipher suites prioritizing forward secrecy
- HSTS headers with preloading
- OCSP stapling enabled

### Automatic Certificate Management

Certificates are automatically provisioned and renewed using Let's Encrypt:

- Wildcard certificates for *.client-domain.com
- 90-day renewal cycle with automatic rotation
- Fallback certificates for development environments

### Backup Encryption

All backups are encrypted:

- Client-specific encryption keys
- Zero-knowledge backup architecture
- Encrypted in transit and at rest

## Security Headers

AgencyStack enforces the following security headers through Traefik middleware:

| Header                      | Value                                      | Purpose                               |
|-----------------------------|--------------------------------------------|------------------------------------- |
| Strict-Transport-Security   | max-age=31536000; includeSubdomains       | Enforce HTTPS connections            |
| X-Content-Type-Options      | nosniff                                    | Prevent MIME type sniffing           |
| X-Frame-Options             | SAMEORIGIN                                 | Prevent clickjacking                 |
| Content-Security-Policy     | default-src 'self'; ...                    | Prevent XSS attacks                  |
| X-XSS-Protection            | 1; mode=block                              | Additional XSS protection            |
| Referrer-Policy             | strict-origin-when-cross-origin            | Control referrer information         |
| Permissions-Policy          | camera=(), microphone=(), geolocation=()   | Restrict browser feature access      |

### Customizing Security Headers

To override the default security headers for a specific service, modify the corresponding Traefik middleware in `/opt/agency_stack/clients/<client_id>/traefik.yml`.

For example, to allow iframe embedding from a trusted domain:

```yaml
http:
  middlewares:
    client-security-headers:
      headers:
        frameDeny: false
        customFrameOptionsValue: "ALLOW-FROM https://trusted-domain.com"
```

## Secrets Management

AgencyStack uses a centralized secrets management approach:

- All secrets stored in `/opt/agency_stack/secrets/`
- Client-specific secrets in `/opt/agency_stack/secrets/<client_id>/`
- Restricted file permissions (700 for directories, 600 for files)
- Secrets accessible only to the `deploy` user and root

### Rotating Secrets

To rotate secrets for a client:

```bash
sudo scripts/security/generate_secrets.sh --rotate --client-id <client_id>
```

To rotate a specific service secret:

```bash
sudo scripts/security/generate_secrets.sh --rotate --client-id <client_id> --service <service_name>
```

## Security Auditing

AgencyStack includes built-in security auditing capabilities:

- Scan for exposed ports
- Check for missing HTTPS configuration
- Validate TLS version and cipher strength
- Verify security headers
- Check for default credentials
- Validate file permissions

To run a security audit:

```bash
sudo make security-audit
```

To automatically fix common issues:

```bash
sudo make security-fix
```

## Multi-tenancy Security

AgencyStack provides strong multi-tenant isolation:

- Each client has dedicated Docker networks
- Separate database instances or schemas
- Client-specific Keycloak realms
- Isolated backup repositories
- Segmented logging

### Client Log Segmentation

Logs are segmented by client in `/var/log/agency_stack/clients/<client_id>/`:

- `access.log`: HTTP access logs
- `error.log`: Error logs from all services
- `audit.log`: Security-related events
- `backup.log`: Backup operations

## Security Best Practices

1. **Regular Updates**: Run `make update` to keep all services updated
2. **Security Audits**: Run `make security-audit` weekly
3. **Credential Rotation**: Rotate secrets regularly
4. **Backup Verification**: Verify backup integrity with `make verify-backup`
5. **Access Review**: Regularly review user access and roles
6. **Monitoring**: Check the Security panel in the dashboard for anomalies

## Security Dashboard

The AgencyStack dashboard includes a Security panel showing:

- Certificate status for all domains
- Open ports and exposed services
- Recent failed login attempts
- SSO integration status
- Audit log summary

## Security Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Keycloak Security Hardening](https://www.keycloak.org/docs/latest/server_admin/index.html#security-vulnerabilities)
- [Traefik Security Guide](https://doc.traefik.io/traefik/v2.0/middlewares/overview/)

## Changelog

### Version 1.0.0 (April 2025)
- Initial implementation of security features
- Added security audit script (`audit_stack.sh`)
- Implemented certificate verification (`verify_certificates.sh`)
- Added authentication verification (`verify_authentication.sh`)
- Integrated security dashboard panel
- Implemented secure secrets management (`generate_secrets.sh`)
- Added security headers in Traefik
- Configured multi-tenant isolation checks (`check_multi_tenancy.sh`)
- Implemented client log segmentation
- Added comprehensive security documentation
