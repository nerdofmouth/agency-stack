---
layout: default
title: Operational Enhancements - AgencyStack Documentation
---

# AgencyStack Operational Features

The AgencyStack platform includes comprehensive operational features for monitoring, alerting, backup verification, and configuration management. This page documents these features and how to use them effectively in production environments.

## Table of Contents

- [Monitoring Stack](#monitoring-stack)
- [Alerting System](#alerting-system)
- [Backup Verification](#backup-verification)
- [Configuration Management](#configuration-management)
- [Automated Tasks](#automated-tasks)
- [Keycloak Integration](#keycloak-integration)

## Monitoring Stack

AgencyStack includes a full-featured monitoring stack based on Loki and Grafana.

### Components

| Component | Description | Default URL |
|-----------|-------------|-------------|
| **Loki** | Log aggregation and storage | https://loki.yourdomain.com |
| **Grafana** | Metrics visualization and dashboards | https://grafana.yourdomain.com |

### Installation

The monitoring stack can be installed during the initial setup by selecting components 32 (Loki) and 33 (Grafana), or later using:

```bash
make monitoring-setup
```

### Accessing Grafana

- **URL**: https://grafana.yourdomain.com
- **Default username**: admin
- **Default password**: Generated during installation (found in `/opt/agency_stack/config.env`)

### Available Dashboards

Pre-configured dashboards include:

1. **AgencyStack Overview**: General system health and log statistics
2. **System Metrics**: Server resources like CPU, memory, disk usage
3. **Docker Containers**: Container status and logs
4. **Application Logs**: Detailed application-specific logging

## Alerting System

The alerting system monitors your AgencyStack installation and notifies you when issues are detected.

### Alert Channels

AgencyStack supports multiple alert channels:

#### Email Alerts

Uses the built-in Mailu email server for sending notifications:

```
# In /opt/agency_stack/config.env
ALERT_EMAIL_ENABLED=true
ALERT_EMAIL_RECIPIENT=admin@yourdomain.com
```

#### Telegram Alerts

Sends notifications to a Telegram chat via bot:

```
# In /opt/agency_stack/config.env
ALERT_TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=your-bot-token
TELEGRAM_CHAT_ID=your-chat-id
```

To create a Telegram bot:
1. Talk to [@BotFather](https://t.me/botfather) on Telegram
2. Use the `/newbot` command to create a new bot
3. Copy the provided token
4. Start a chat with your bot and get the chat ID using https://api.telegram.org/bot{YOUR_TOKEN}/getUpdates

#### Webhook Alerts

Sends JSON alerts to any webhook endpoint (for Discord, Slack, custom integrations):

```
# In /opt/agency_stack/config.env
ALERT_WEBHOOK_ENABLED=true
WEBHOOK_URL=https://your-webhook-url
```

### Testing Alerts

To verify your alert configuration is working:

```bash
make test-alert
```

This will send a test alert through all configured channels.

## Backup Verification

AgencyStack includes automated verification of Restic backups to ensure data integrity.

### Manual Verification

To manually verify backup integrity:

```bash
make verify-backup
```

This will:
1. Check repository integrity with `restic check`
2. Verify a sample of data from the latest snapshot
3. Generate a report at `/var/log/agency_stack/restic_verification-*.log`

### Verification Summary

Each verification run creates a summary at `/var/log/agency_stack/restic_verification_latest.log` which includes:
- Status (passed/failed)
- Number of errors
- Last backup time
- Total backup size
- File count

## Configuration Management

AgencyStack uses Git to track and manage configuration changes, enabling version control and rollback capabilities.

### Configuration Snapshots

To save the current configuration state:

```bash
make config-snapshot
```

This creates a Git commit with all configuration files, including:
- `.env` files
- `docker-compose.yml` files
- Component-specific configurations
- Traefik routing rules

### Viewing Configuration History

To see previous configuration states:

```bash
make config-diff
```

This shows all available snapshots and allows you to view specific changes.

### Configuration Rollback

To revert to a previous configuration state:

```bash
make config-rollback
```

This interactive command will:
1. Show available snapshots
2. Prompt for the commit hash to restore
3. Apply the selected configuration after confirmation

> **Warning**: After rollback, you may need to restart services for changes to take effect.

## Automated Tasks

AgencyStack includes scheduled tasks for ongoing system maintenance and monitoring.

### Setting Up Automated Tasks

```bash
make setup-cron
```

This installs the following cron jobs:

| Task | Schedule | Description |
|------|----------|-------------|
| Health Check | Hourly | Verifies all components are working correctly |
| Backup Verification | Weekly (Sunday 2 AM) | Checks backup integrity |
| Config Snapshot | Daily (3 AM) | Takes automatic configuration backup |
| DNS Verification | Daily (4 AM) | Validates DNS configuration |
| Log Cleanup | Daily (5 AM) | Removes logs older than 30 days |

### Logs

All automated task output is logged to `/var/log/agency_stack/` with the following naming convention:
- `health_check_cron.log`
- `backup_verify_cron.log`
- `config_snapshot_cron.log`
- `dns_verify_cron.log`

To view logs interactively:

```bash
make logs
```

This opens a menu interface for browsing, filtering, and exporting logs.

## Keycloak Integration

AgencyStack supports integration with Keycloak (component #25) for centralized identity management and single sign-on (SSO) across all components.

### Overview

Integrating Keycloak provides the following benefits:

- Single sign-on (SSO) across all AgencyStack components
- Centralized user management
- Enhanced security with MFA options
- Role-based access control across services
- Consistent login experience

### Keycloak Integration Setup

To integrate Keycloak with your AgencyStack components:

```bash
make integrate-keycloak
```

This script:
1. Creates an "agencystack" realm in Keycloak
2. Sets up required clients for each compatible component
3. Creates initial admin user credentials
4. Reconfigures components to use Keycloak authentication
5. Establishes Traefik integration for global authentication

### Components Supporting Keycloak Integration

The following AgencyStack components support direct Keycloak integration:

| Component | Integration Type | Notes |
|-----------|------------------|-------|
| Grafana | Native OAuth | Full role mapping support |
| Loki | Via Traefik Auth | Uses forward authentication |
| Mailu Admin | Via Traefik Auth | Uses forward authentication |
| Portainer | Coming soon | |
| Nextcloud | Coming soon | |

### Accessing Protected Services

After integration, you can access services in two ways:

1. **Direct OAuth Login**: For services with native Keycloak integration (like Grafana), you'll see a "Login with Keycloak" button on the login page.

2. **Traefik Forward Authentication**: For services using forward authentication, you'll be automatically redirected to the Keycloak login page when accessing the service.

### Default Roles

The Keycloak integration creates three standard roles in the AgencyStack realm:

- **admin**: Full administrative access to all services
- **editor**: Can modify content but not manage system settings
- **viewer**: Read-only access to dashboards and content

### Manual Configuration

If you need to manually configure Keycloak integration:

1. Log in to the Keycloak admin console at `https://keycloak.yourdomain.com`
2. Navigate to the "agencystack" realm
3. Configure clients for each service
4. Set up appropriate role mappings

### Troubleshooting

If you encounter issues with Keycloak integration:

1. Check Keycloak logs:
   ```bash
   docker logs agency_stack_keycloak
   ```

2. Check Traefik Forward Auth logs:
   ```bash
   docker logs agency_stack_traefik_auth
   ```

3. Verify that DNS records are correctly set up for all domains

4. Ensure that Keycloak is accessible at `https://keycloak.yourdomain.com`
