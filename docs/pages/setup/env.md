# AgencyStack Environment Configuration

This document describes all environment variables used by AgencyStack components. These variables can be set in a `.env` file in the root directory of your AgencyStack installation.

## Basic Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DOMAIN` | Primary domain for your AgencyStack installation | `agency.example.com` | Yes |
| `CLIENT_ID` | Identifier for the default client | `default` | Yes |
| `ADMIN_EMAIL` | Email address for the admin user | - | Yes |
| `ADMIN_PASSWORD` | Initial password for the admin user (change immediately) | - | Yes |
| `INSTALLATION_TYPE` | Type of installation: minimal, core, full, or custom | `full` | No |

## Security Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ENABLE_SSL` | Enable SSL/TLS for all services | `true` | No |
| `ENABLE_FAIL2BAN` | Enable Fail2Ban for brute force protection | `true` | No |
| `ENABLE_CROWDSEC` | Enable CrowdSec for intelligent threat detection | `true` | No |
| `SECURITY_LEVEL` | Security level (basic, standard, high, extreme) | `high` | No |
| `ENABLE_AUTO_UPDATES` | Enable automatic updates for components | `false` | No |
| `SECRET_KEY` | Secret key for encrypt/decrypt operations | - | Yes |
| `JWT_SECRET` | Secret for JWT token generation | - | Yes |

## Authentication and SSO

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ENABLE_SSO` | Enable Single Sign-On with Keycloak | `true` | No |
| `KEYCLOAK_URL` | URL of the Keycloak server | - | Yes, if SSO enabled |
| `KEYCLOAK_REALM` | Keycloak realm for AgencyStack | `agency_stack` | Yes, if SSO enabled |
| `KEYCLOAK_CLIENT_ID` | Client ID for AgencyStack in Keycloak | `agency_dashboard` | Yes, if SSO enabled |
| `KEYCLOAK_CLIENT_SECRET` | Client secret for AgencyStack in Keycloak | - | Yes, if SSO enabled |

## Email Configuration (Mailu)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `MAIL_SERVER` | Hostname for the mail server | - | Yes, for email |
| `POSTMASTER` | Email address for the postmaster | - | Yes, for email |
| `MAIL_DOMAIN` | Primary mail domain | - | Yes, for email |
| `ENABLE_DKIM` | Enable DKIM signing for outgoing emails | `true` | No |
| `DKIM_SELECTOR` | DKIM selector for DNS records | `mail` | Yes, if DKIM enabled |
| `MAIL_WEBMAIL` | Webmail client (roundcube, etc.) | `roundcube` | No |

## Database Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DB_TYPE` | Database type: postgresql or mysql | `postgresql` | No |
| `DB_HOST` | Database host | `localhost` | Yes |
| `DB_PORT` | Database port | `5432` | Yes |
| `DB_USER` | Database username | `agency_stack` | Yes |
| `DB_PASSWORD` | Database password | - | Yes |
| `DB_NAME` | Database name | `agency_stack` | Yes |

## AI and Automation

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ENABLE_AI` | Enable AI components | `true` | No |
| `ENABLE_OPENAI` | Use external OpenAI APIs (disabled by default) | `false` | No |
| `OPENAI_API_KEY` | OpenAI API key | - | Yes, if OpenAI enabled |
| `ENABLE_OLLAMA` | Enable Ollama for local LLM serving | `true` | No |
| `ENABLE_LANGCHAIN` | Enable LangChain for AI pipelines | `true` | No |
| `VECTOR_DB_TYPE` | Vector database: chroma, qdrant, or weaviate | `chroma` | Yes, if AI enabled |

## Infrastructure

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DOCKER_REGISTRY` | Docker registry URL | `docker.io` | No |
| `ENABLE_PORTAINER` | Enable Portainer for Docker management | `true` | No |
| `ENABLE_TRAEFIK` | Enable Traefik as reverse proxy | `true` | No |
| `METRICS_ENABLED` | Enable metrics collection | `true` | No |
| `LOKI_RETENTION_DAYS` | Number of days to retain logs in Loki | `30` | No |
| `PROMETHEUS_RETENTION_DAYS` | Number of days to retain metrics in Prometheus | `15` | No |
| `LOG_LEVEL` | Logging level (debug, info, warn, error) | `info` | No |

## Component-specific Configurations

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PEERTUBE_ADMIN_EMAIL` | Admin email for PeerTube | - | Yes, for PeerTube |
| `PEERTUBE_ADMIN_PASSWORD` | Admin password for PeerTube | - | Yes, for PeerTube |
| `WORDPRESS_URL` | URL for WordPress site | - | Yes, for WordPress |
| `GHOST_URL` | URL for Ghost blog | - | Yes, for Ghost |
| `SEAFILE_URL` | URL for Seafile file server | - | Yes, for Seafile |
| `FOCALBOARD_URL` | URL for Focalboard | - | Yes, for Focalboard |

## Multi-tenancy Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ENABLE_MULTI_TENANCY` | Enable multi-tenant mode | `true` | No |
| `DEFAULT_CLIENT_ID` | ID of the default client | `default` | Yes, if multi-tenancy enabled |
| `CLIENT_ISOLATION_LEVEL` | Level of client isolation (shared, partial, full) | `full` | No |

## Resource Limits

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `MAX_CONTAINER_MEMORY` | Maximum memory per container | `2g` | No |
| `MAX_CONTAINER_CPU` | Maximum CPU cores per container | `1.0` | No |
| `DISK_QUOTA_GB` | Disk quota in GB | `100` | No |

## Setting Up Your Environment

1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file with your specific configuration:
   ```bash
   nano .env
   ```

3. Validate your environment settings:
   ```bash
   make env-check
   ```

4. Apply the settings to your installation:
   ```bash
   make install-all
   ```
