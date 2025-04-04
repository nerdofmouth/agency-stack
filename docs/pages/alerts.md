# AgencyStack Alerts & Notifications

AgencyStack includes a comprehensive alerting and notification system to keep you informed about the health and status of your infrastructure. This document explains how to configure, use, and customize the alerting system.

## Overview

The alerting system provides:

- **Email notifications** via Mailu's SMTP relay
- **Telegram notifications** via Telegram Bot API
- **Centralized logging** of all alerts
- **Dashboard integration** for viewing and monitoring alerts
- **Automated alert triggering** from health checks, backups, and more

## Alert Channels

AgencyStack supports multiple notification channels:

### Email Alerts

Email alerts use the Mailu component as the SMTP relay. When Mailu is installed, AgencyStack automatically configures email alerts to use it.

#### Configuration

In your `/opt/agency_stack/config.env`, set the following variables:

```bash
# Email alert configuration
ALERT_EMAIL_ENABLED=true
ALERT_EMAIL_FROM="alerts@yourdomain.com"
ALERT_EMAIL_TO="admin@yourdomain.com"
ALERT_EMAIL_SERVER="mail.yourdomain.com"
ALERT_EMAIL_PORT=587
ALERT_EMAIL_USER="alerts@yourdomain.com"
ALERT_EMAIL_PASSWORD="your-secure-password"
```

If you're using Mailu, these variables will be automatically populated from your Mailu configuration.

### Telegram Alerts

Telegram alerts require a Telegram Bot Token and Chat ID.

#### Configuration

In your `/opt/agency_stack/config.env`, set the following variables:

```bash
# Telegram alert configuration
ALERT_TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

To set up a Telegram bot:
1. Contact [@BotFather](https://t.me/botfather) on Telegram
2. Create a new bot using `/newbot` command
3. Copy the provided API token
4. Start a conversation with your new bot
5. Use [@userinfobot](https://t.me/userinfobot) to get your Chat ID

## Alert Triggers

Alerts are triggered by:

1. **Health Checks** - Daily automated health checks will alert if services are down
2. **Backup Verification** - Weekly backup checks will alert if backups are invalid or missing
3. **Integration Issues** - Alerts if integration processes fail
4. **Port Conflicts** - Alerts for detected port conflicts (when enabled)
5. **Manual Triggers** - Using `make test-alert` for testing

## Alert Configuration

### Common Options

The alerting system behavior is configured through environment variables in `/opt/agency_stack/config.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `ALERT_ON_FAILURE` | `false` | Send alerts when health checks, backups, or integrations fail |
| `ALERT_EMAIL_ENABLED` | `true` | Enable email alerts |
| `ALERT_TELEGRAM_ENABLED` | `true` | Enable Telegram alerts |

### Setting Alert Thresholds

You can customize alert thresholds in `/opt/agency_stack/config.env`:

```bash
# Alert thresholds
HEALTH_CHECK_THRESHOLD=1       # Number of consecutive failures before alerting
DISK_SPACE_THRESHOLD=85        # Percentage of disk use that triggers alerts
MEMORY_THRESHOLD=90            # Percentage of memory use that triggers alerts
```

## Alert Logging

All alerts are logged to `/var/log/agency_stack/alerts.log` with the following format:

```
YYYY-MM-DD HH:MM:SS [ALERT] Alert Title - Alert Message
```

View recent alerts using:

```bash
make view-alerts
```

## Alert Dashboard

The Alerts & Logs section in the AgencyStack dashboard provides:

- **Real-time log viewing** - See alerts and logs from all components
- **Filtering capabilities** - Filter by alert type, component, or status
- **Alert summaries** - Quick overview of system health
- **Testing functionality** - Send test alerts directly from the UI

Access it by:
1. Open the AgencyStack dashboard (`make dashboard-open`)
2. Click the "Alerts & Logs" tab in the navigation

## Testing Alerts

To send a test alert to all configured channels:

```bash
make test-alert
```

This will trigger a test alert message to verify your configuration.

## Custom Alert Scripts

You can create custom alert triggers by using the notification scripts directly:

### Email Only

```bash
/opt/agency_stack/scripts/notifications/notify_email.sh "Subject" "Message body"
```

### Telegram Only

```bash
/opt/agency_stack/scripts/notifications/notify_telegram.sh "Subject" "Message body"
```

### All Channels

```bash
/opt/agency_stack/scripts/notifications/notify_all.sh "Subject" "Message body"
```

## Troubleshooting

### Email Alerts Not Working

1. Verify Mailu is running: `docker ps | grep mailu`
2. Check Mailu configuration in `/opt/agency_stack/mailu/.env`
3. Validate email settings in `/opt/agency_stack/config.env`
4. View email logs: `docker logs mailu-front`

### Telegram Alerts Not Working

1. Verify bot token is correct
2. Ensure the bot is added to the chat
3. Check if the chat ID is correct
4. Verify network connectivity

### Alert Logs Missing

1. Ensure log directory exists: `sudo mkdir -p /var/log/agency_stack`
2. Check permissions: `sudo chmod 755 /var/log/agency_stack`
3. Run `make setup-log-rotation` to set up proper logging

## Related Commands

- `make test-alert` - Send a test alert
- `make view-alerts` - Show recent alerts
- `make log-summary` - Display summary of all logs
- `make setup-cronjobs` - Set up automated health checks and alerts
- `make dashboard-update` - Update the dashboard with latest alert data
