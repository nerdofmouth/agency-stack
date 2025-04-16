# AgencyStack Integrations

This document provides an overview of integrations between various AgencyStack components, detailing how different services work together to provide a cohesive platform.

## Available Integrations

AgencyStack provides several integration types to connect components:

| Integration Type | Description | Command |
|-----------------|-------------|---------|
| **Email** | Connect components to Mailu for email delivery | `make integrate-email` |
| **Single Sign-On** | Unify authentication with Keycloak | `make integrate-sso` |
| **Monitoring** | Centralized logging and metrics with Loki/Grafana | `make integrate-monitoring` |
| **Data Exchange** | Data sharing between WordPress and ERPNext | `make integrate-data-bridge` |
| **All Integrations** | Run all integration types at once | `make integrate-components` |

## Email Integration

The email integration connects AgencyStack components to [Mailu](https://mailu.io), which provides a full-featured mail server with SMTP, IMAP, webmail interface (Roundcube), and admin panel.

### Components Supported

| Component | Integration Details |
|-----------|---------------------|
| **WordPress** | Configures the WP Mail SMTP plugin to use Mailu for all WordPress emails |
| **ERPNext** | Sets up ERPNext to use Mailu for notifications and transactional emails |
| **Future: Listmonk** | Newsletter and mailing list manager integration |
| **Future: Chatwoot** | Support ticket notification emails |

### Configuration

The integration automatically configures:

- SMTP server settings (host, port, encryption)
- Authentication credentials
- Default sender addresses
- Email domain configuration

### Usage

```bash
make integrate-email
```

## Single Sign-On Integration

The Single Sign-On (SSO) integration connects components to [Keycloak](https://www.keycloak.org/) for centralized authentication, enabling users to log in once and access all integrated services.

### Components Supported

| Component | Integration Details |
|-----------|---------------------|
| **WordPress** | Uses miniOrange OIDC plugin for WordPress SSO with Keycloak |
| **ERPNext** | Configures OAuth provider settings for Keycloak authentication |
| **Grafana** | Sets up OAuth authentication with Keycloak including role mapping |
| **Future: Others** | Any component supporting OAuth2/OIDC will be added |

### Configuration

The integration automatically configures:

- OAuth client registration
- Endpoint URLs (authorization, token, userinfo)
- Role mapping between Keycloak and applications
- Redirect URIs for proper authentication flow

### Usage

```bash
make integrate-sso
```

## Monitoring Integration

The monitoring integration connects components to [Loki](https://grafana.com/oss/loki/) for centralized logging and [Grafana](https://grafana.com/) for visualization, enabling comprehensive observability across all services.

### Components Supported

| Component | Integration Details |
|-----------|---------------------|
| **WordPress** | Sets up log parsing pipeline for WordPress logs |
| **ERPNext** | Configures Loki to collect and parse Frappe/ERPNext logs |
| **Mailu** | Enables mail server log collection and parsing |
| **Grafana** | Creates preconfigured dashboards for all components |
| **Uptime Kuma** | Configures health check endpoints for all services |

### Configuration

The integration automatically configures:

- Loki log collection pipelines for each component
- Log parsing rules for structured logging
- Grafana dashboards for visualization
- Health check endpoints for uptime monitoring

### Usage

```bash
make integrate-monitoring
```

## Data Exchange Bridge

The data exchange bridge enables bidirectional data sharing between components, starting with WordPress and ERPNext integration to synchronize users, products, orders, and content.

### Components Supported

| Component Pair | Integration Details |
|----------------|---------------------|
| **WordPress ↔ ERPNext** | Bidirectional sync of users, products, orders, and contact forms |

### Configuration

The integration automatically configures:

- WordPress plugin for ERPNext connectivity
- ERPNext app for WordPress integration
- API endpoints for data exchange
- Configuration UI for controlling what data is shared

### Usage

```bash
make integrate-data-bridge
```

## Integration State Management

AgencyStack maintains records of applied integrations in `/opt/agency_stack/integrations/state/`, enabling:

- **Idempotent operations**: Running an integration multiple times won't break anything
- **Status tracking**: See which integrations have been applied and when
- **Version management**: Track integration versions and updates

## Extending Integrations

Integrations can be extended by modifying the relevant scripts in the `scripts/integration` directory. Each integration type has its own module, making it easy to add support for new components or enhance existing integrations.

## Troubleshooting

If an integration fails or you need to debug issues:

1. Check the integration logs in `/var/log/agency_stack/`
2. Run with `--auto` flag for non-interactive mode: `sudo make integrate-components -- --auto`
3. View the integration state files in `/opt/agency_stack/integrations/state/`

## Best Practices

1. **Run integrations after installation**: Always run the appropriate integration after installing new components
2. **Keep components updated**: Ensure all components are up-to-date before running integrations
3. **Check integration versions**: Re-run integrations after major version updates
4. **Use specific integration types**: Use targeted integration commands rather than running all integrations at once

## Port Management & Conflict Resolution

AgencyStack provides robust tools for managing port assignments and resolving conflicts between services.

### Port Registry

All ports used by AgencyStack components are tracked in a central registry:

- **Location**: `/opt/agency_stack/ports/ports.json`
- **Format**: JSON mapping of ports to services
- **Purpose**: Prevent conflicts, enable port remapping, document assignments

### Port Detection Tools

AgencyStack includes utilities to detect and resolve port conflicts:

| Command | Description | Use Case |
|---------|-------------|----------|
| `make detect-ports` | Scan for conflicts without making changes | Before deployments or when troubleshooting |
| `make remap-ports` | Automatically resolve conflicts by reassigning ports | When conflicts are detected |
| `make scan-ports` | Only scan and update the port registry | After manual changes to the infrastructure |

### How Port Conflict Detection Works

1. **Registry Scanning**: Reads the current port registry from `ports.json`
2. **Docker Container Analysis**: Examines all running containers for port mappings 
3. **System Port Check**: Verifies if any ports are in use by the host system
4. **Conflict Detection**: Identifies port collisions and duplications
5. **Resolution**: Suggests or automatically applies port reassignments

### Conflict Resolution Strategies

When a conflict is detected, the system:

1. Identifies an available port in the 8000-9000 range (customizable)
2. Updates `ports.json` with the new assignment
3. Modifies service configuration files (including `.env` files and Docker Compose config)
4. Records the decision in `/opt/agency_stack/ports/decisions.log` for auditing

### Best Practices for Port Management

1. **Use Environment Variables**: Always reference ports as `${PORT_SERVICENAME}` in configuration files
2. **Run Detection Regularly**: Especially before adding new components
3. **Review the Decisions Log**: Check `/opt/agency_stack/ports/decisions.log` for port reassignment history
4. **Restart Services**: After port remapping, restart affected services to apply changes

### Common Port Assignments

| Service | Default Port | Notes |
|---------|--------------|-------|
| Traefik | 80, 443 | Web traffic and HTTPS |
| Portainer | 9000 | Container management |
| WordPress | 8080 | Content management system |
| ERPNext | 8000 | Business management platform |
| Grafana | 3000 | Monitoring dashboards |
| Loki | 3100 | Log aggregation |
| Mailu | 25, 465, 587, 993, 995 | Email services |
| Keycloak | 8443 | Identity management |

### Handling Manual Port Changes

If you need to change ports manually:

1. Edit the relevant Docker Compose file or service configuration
2. Update the environment variables in `.env` files
3. Run `make scan-ports` to update the port registry
4. Restart the affected services

This systematic approach ensures that port conflicts are detected early and resolved automatically, reducing downtime and configuration errors across the AgencyStack ecosystem.
