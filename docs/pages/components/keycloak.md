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

| Parameter         | Value                                 |
|------------------|---------------------------------------|
| **Version**      | Latest (Quarkus-based)                |
| **Default URL**  | https://yourdomain.com/admin           |
| **Web Port**     | 8080 (internal)                       |
| **Container Image** | quay.io/keycloak/keycloak:latest    |
| **Data Directory**   | /opt/agency_stack/keycloak/{DOMAIN}/|
| **Log File**         | /var/log/agency_stack/components/keycloak.log |

## Installation

### Prerequisites
- Docker and Docker Compose
- Traefik configured with Let's Encrypt
- Domain name properly configured in DNS
- PostgreSQL database (automatically installed as a dependency)

### Installation Commands

**Standard Installation:**
```bash
make keycloak DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com
```

**With Optional Parameters:**
```bash
make keycloak DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com CLIENT_ID=customclient FORCE=true WITH_DEPS=true VERBOSE=true ENABLE_CLOUD=true ENABLE_OPENAI=true USE_GITHUB=true ENABLE_KEYCLOAK=true
```

### Installation Options (Flags)
- `--domain`: Domain name for Keycloak (**required**)
- `--admin-email`: Admin email for notifications (**required**)
- `--client-id`: Client ID for multi-tenancy (optional)
- `--verbose`: Enable verbose output
- `--force`: Force installation even if already installed
- `--with-deps`: Install dependencies automatically
- `--enable-cloud`: Enable cloud integration (optional)
- `--enable-openai`: Enable OpenAI integration (optional)
- `--use-github`: Use GitHub as an integration source (optional)
- `--enable-keycloak`: Explicitly enable Keycloak SSO integration (optional; triggers readiness checks)
- `--help`: Show help message and exit

## Makefile Targets

| Target                | Description                                    |
|----------------------|------------------------------------------------|
| `make keycloak`      | Install Keycloak and all dependencies          |
| `make keycloak-status` | Check Keycloak status and OAuth configuration |
| `make keycloak-logs` | View Keycloak logs                             |
| `make keycloak-restart` | Restart Keycloak services                   |
| `make keycloak-test` | Test Keycloak API/admin endpoint               |

## Configuration

### Default Configuration
- All configuration files are stored in `/opt/agency_stack/keycloak/{DOMAIN}/`.
- Environment variables can be set in `.env` files or passed as Makefile variables.

## Security Considerations
- OAuth, OIDC, and SAML are supported and configurable.
- Role-based access control (RBAC) is enforced via Keycloak groups.
- Multi-tenancy is supported through isolated realms.
- Logs are stored at `/var/log/agency_stack/components/keycloak.log`.

## Troubleshooting
- Use `make keycloak-logs` to view logs.
- Use `make keycloak-status` to check component health.
- For advanced debugging, consult the Keycloak admin console at `https://yourdomain.com/admin`.

## References
- [Keycloak Documentation](https://www.keycloak.org/documentation.html)
- [AgencyStack Documentation](https://stack.nerdofmouth.com)
