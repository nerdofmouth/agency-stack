# Uptime Kuma

Uptime Kuma provides comprehensive monitoring for all AgencyStack components, offering real-time status tracking, alerting, and historical uptime data.

## Overview

Uptime Kuma serves as the central monitoring solution for AgencyStack, providing:

- Real-time status monitoring of all services
- Detailed uptime history and statistics
- Flexible notification options (email, Slack, Discord, etc.)
- Status page for client-facing uptime reports
- Integration with the AgencyStack dashboard

![Uptime Kuma Dashboard](https://uptime.kuma.pet/img/dashboard.png)

## Installation

```bash
# Install with default settings
make uptime-kuma DOMAIN=yourdomain.com

# With Keycloak SSO integration
make uptime-kuma DOMAIN=yourdomain.com ENABLE_KEYCLOAK=true

# Full secure installation with all options
make uptime-kuma DOMAIN=yourdomain.com ENABLE_KEYCLOAK=true ENFORCE_HTTPS=true
```

### Installation Options

The installation script supports the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `--domain` | Domain name for the installation | Required |
| `--client-id` | Client identifier for multi-tenant deployments | default |
| `--enable-keycloak` | Enable Keycloak SSO integration | false |
| `--enforce-https` | Force HTTPS for secure access | true |
| `--port` | Port for the Uptime Kuma service | 3001 |
| `--force` | Force reinstallation if already installed | false |
| `--with-deps` | Install dependencies automatically | false |
| `--verbose` | Show detailed output during installation | false |

## Configuration

Uptime Kuma requires minimal configuration as it's designed to be user-friendly. Key configuration areas include:

### Monitor Configuration

Monitors can be configured through the web interface for various services:

- **HTTP/HTTPS**: For web services and APIs
- **TCP/UDP**: For database and network services
- **DNS**: For domain name resolution checks
- **Ping**: For basic network connectivity
- **Push**: For application heartbeat monitoring

### Alert Notifications

Configure alerts to be sent via:

- Email
- Slack
- Discord
- Telegram
- Webhook
- PagerDuty
- and many more

### Status Page

A public status page can be configured to show service status to clients and users:

- Custom branding and logo
- Service grouping
- Incident history
- Maintenance windows

## Integration with AgencyStack Dashboard

Uptime Kuma is integrated with the AgencyStack dashboard to provide centralized monitoring:

1. Status indicators display on the dashboard for all components
2. Critical alerts are shown in the dashboard notification center
3. Uptime history is accessible through the dashboard reporting interface

## SSO Integration

When installed with `--enable-keycloak`, Uptime Kuma is configured to use Keycloak for authentication, providing:

- Single sign-on across AgencyStack components
- Role-based access control for monitoring data
- User audit logging for monitoring changes
- Secure authentication with MFA support

### Verification

To verify SSO integration:

1. Check the component registry: `make uptime-kuma-status`
2. Verify you can access Uptime Kuma through the SSO login
3. Confirm SSO configuration in the Keycloak admin console

## Paths

| Path | Description |
|------|-------------|
| `/opt/agency_stack/clients/{client_id}/apps/uptime-kuma` | Installation directory |
| `/opt/agency_stack/clients/{client_id}/apps/uptime-kuma/data` | Persistent data |
| `/var/log/agency_stack/components/uptime-kuma` | Log files |

## Troubleshooting

If Uptime Kuma is not working as expected:

1. Check the logs: `make uptime-kuma-logs`
2. Verify Traefik routing: `make traefik-status`
3. Ensure the container is running: `docker ps | grep uptime-kuma`
4. Check network connectivity between components

## Component Registry Metadata

Uptime Kuma supports the following component registry flags:

```json
{
  "monitoring": true,
  "traefik_tls": true,
  "sso_configured": true,
  "multi_tenant": true
}
```

## Related Components

- [Dashboard](dashboard.md): Central interface that displays Uptime Kuma data
- [Traefik](traefik.md): Provides routing and TLS for Uptime Kuma
- [Keycloak](keycloak.md): Provides SSO authentication when enabled
