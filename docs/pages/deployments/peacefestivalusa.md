# PeaceFestival USA Deployment Documentation

## Overview

This document details the production deployment of PeaceFestival USA on the AgencyStack infrastructure, following Charter v1.0.3 principles of Repository as Source of Truth, Strict Containerization, and Multi-Tenancy & Security.

| Aspect | Details |
|--------|---------|
| **Client ID** | `peacefestivalusa` |
| **Domain** | `peacefestivalusa.alpha.nerdofmouth.com` |
| **Components** | WordPress, Keycloak, Traefik, Portainer |
| **Deployment Date** | 2025-05-09 |
| **Charter Alignment** | Phase 1-2 (Infrastructure Foundation, Content & Media Management) |

## Deployment Configuration

### Component Versions

| Component | Version | Container Image |
|-----------|---------|----------------|
| WordPress | 6.4 | wordpress:6.4-php8.2-apache |
| MariaDB | 10.11 | mariadb:10.11 |
| Keycloak | 22.0.1 | quay.io/keycloak/keycloak:22.0.1 |
| Traefik | 2.10 | traefik:2.10 |
| Portainer | 2.19.0 | portainer/portainer-ce:2.19.0 |

### Deployment Flags

```bash
--enable-keycloak      # Integrates with Keycloak SSO
--enable-cloud         # Enables cloud storage integration
--multi-tenant         # Configures for multi-tenant isolation
```

### Network Configuration

- **Internal Network**: `peacefestival_network` (isolated client network)
- **Shared Network**: `traefik_network` (for reverse proxy)
- **TLS Configuration**: Let's Encrypt with auto-renewal
- **Security Headers**: HSTS, Content-Security-Policy, X-Frame-Options

## Installation Procedure

Following the AgencyStack Charter v1.0.3 "Repository as Source of Truth" principle, all installation steps are defined in repository-tracked scripts:

```bash
# 1. Base Infrastructure (Traefik + Keycloak)
make traefik-keycloak DOMAIN=alpha.nerdofmouth.com ADMIN_EMAIL=admin@nerdofmouth.com

# 2. Client-Specific WordPress Installation
make peacefestivalusa-wordpress DOMAIN=peacefestivalusa.alpha.nerdofmouth.com \
  ADMIN_EMAIL=admin@peacefestivalusa.com \
  --enable-keycloak \
  --enable-cloud \
  --multi-tenant

# 3. Portainer Installation (Management UI)
make portainer DOMAIN=manage.alpha.nerdofmouth.com
```

## Directory Structure

Following AgencyStack Charter v1.0.3 directory conventions:

```
/opt/agency_stack/clients/peacefestivalusa/
├── wordpress/          # WordPress core files
├── wordpress-custom/   # Custom themes and plugins
├── db_data/            # MariaDB database files
├── backups/            # Regular backups
└── logs/               # Component-specific logs
```

## Environment Variables

Environmental variables are stored in `/opt/agency_stack/clients/peacefestivalusa/.env` and adhere to the principle of "Auditability & Documentation":

```
CLIENT_ID=peacefestivalusa
DOMAIN=peacefestivalusa.alpha.nerdofmouth.com
WORDPRESS_DEBUG=false
ENABLE_KEYCLOAK=true
ENABLE_CLOUD=true
MULTI_TENANT=true
```

## Testing & Validation

Following the TDD Protocol defined in the AgencyStack Charter:

1. **Unit Tests**: Component-level tests executed during installation
2. **Integration Tests**: Inter-component communication verification
3. **End-to-End Tests**: User workflow validation with Puppeteer
4. **Security Tests**: Penetration testing and security scanning

## Monitoring & Logs

All logs are stored following Charter v1.0.3 logging standards:

```
/var/log/agency_stack/clients/peacefestivalusa/wordpress.log
/var/log/agency_stack/clients/peacefestivalusa/mariadb.log
/var/log/agency_stack/components/traefik/traefik.log
/var/log/agency_stack/components/keycloak/keycloak.log
/var/log/agency_stack/components/portainer/portainer.log
```

## Security Considerations

- **Tenant Isolation**: Complete network and resource isolation
- **Authentication**: Keycloak SSO with MFA enabled
- **Authorization**: Role-based access control
- **Data Protection**: At-rest and in-transit encryption
- **Auditing**: Comprehensive action logging

## Maintenance Procedures

1. **Backups**: Daily automated backups to `/opt/agency_stack/clients/peacefestivalusa/backups`
2. **Updates**: Weekly security patches applied via repository-tracked scripts
3. **Monitoring**: Health checks every 5 minutes
4. **Alerting**: Email notifications for critical issues

## Charter Compliance

This deployment strictly adheres to AgencyStack Charter v1.0.3 principles:
- **Repository as Source of Truth**: All configuration tracked in git
- **Idempotency & Automation**: All scripts are rerunnable
- **Strict Containerization**: No host-level contamination
- **Multi-Tenancy & Security**: Complete client isolation
- **Auditability & Documentation**: This document plus in-code documentation
