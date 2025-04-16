# AgencyStack Scheduled Tasks

AgencyStack uses scheduled tasks (cron jobs) to automate routine maintenance, health checks, and other important operations. This document explains how to set up, customize, and manage scheduled tasks.

## Overview

The scheduled tasks system provides:

- **Daily health checks** to ensure all services are running properly
- **Weekly backup verification** to confirm data is properly backed up
- **Hourly dashboard updates** to keep the dashboard current
- **Daily integration refreshes** to maintain component connections
- **Centralized logging** of all scheduled task outputs
- **Alert integration** to notify you of issues

## Scheduled Tasks

AgencyStack includes the following scheduled tasks:

| Task | Schedule | Description | Log File |
|------|----------|-------------|----------|
| Health Check | Daily at 02:00 | Verifies all services are running properly | `/var/log/agency_stack/health.log` |
| Backup Verification | Weekly on Sundays at 03:00 | Confirms data is properly backed up | `/var/log/agency_stack/backup.log` |
| Dashboard Update | Hourly | Updates dashboard data to reflect current state | `/var/log/agency_stack/dashboard.log` |
| Integrations Refresh | Daily at 01:00 | Maintains component integrations | `/var/log/agency_stack/integration.log` |

## Setup

To install all scheduled tasks at once:

```bash
make setup-cronjobs
```

This command:
1. Makes all cron scripts executable
2. Creates necessary log directories
3. Adds cron jobs to the system crontab
4. Sets up log rotation
5. Avoids duplicating jobs if run multiple times

## Configuration

### Environment Variables

Scheduled tasks behavior is configured through environment variables in `/opt/agency_stack/config.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `ALERT_ON_FAILURE` | `false` | Send alerts when scheduled tasks fail |
| `HEALTH_CHECK_COMPONENTS` | `all` | Comma-separated list of components to check (or "all") |
| `BACKUP_VERIFY_COMPONENTS` | `all` | Comma-separated list of components to verify backups for |
| `DASHBOARD_UPDATE_INTERVAL` | `hourly` | How often to update dashboard (hourly, daily, etc.) |

### Customizing Schedule

To modify the schedule of a task:

1. Edit the crontab directly:
   ```bash
   sudo crontab -e
   ```

2. Locate the relevant task and modify the schedule part (first 5 fields)
   ```
   # Format: minute hour day_of_month month day_of_week command
   0 2 * * * /opt/agency_stack/scripts/cronjobs/health_check_cron.sh > /var/log/agency_stack/cron/health_check_cron.sh.log 2>&1
   ```

3. Save and exit the editor

## Log Files

All scheduled tasks write to log files in these locations:

- **Task-specific logs**: `/var/log/agency_stack/`
  - `health.log` - Health check results
  - `backup.log` - Backup verification results
  - `integration.log` - Integration refresh results
  - `dashboard.log` - Dashboard update results

- **Cron job logs**: `/var/log/agency_stack/cron/`
  - Contains the raw output from each cron job execution

### Log Rotation

All logs are automatically rotated daily and compressed after 7 days to prevent disk space issues. This is configured in `/etc/logrotate.d/agency_stack_cron`.

## Manual Execution

You can manually run any scheduled task:

```bash
# Health check
sudo /opt/agency_stack/scripts/cronjobs/health_check_cron.sh

# Backup verification
sudo /opt/agency_stack/scripts/cronjobs/backup_verify_cron.sh

# Dashboard update
sudo /opt/agency_stack/scripts/cronjobs/dashboard_update_cron.sh

# Integrations refresh
sudo /opt/agency_stack/scripts/cronjobs/integrations_refresh_cron.sh
```

Add the `--alert` flag to force alert notifications regardless of your configuration:

```bash
sudo /opt/agency_stack/scripts/cronjobs/health_check_cron.sh --alert
```

## Disabling Tasks

To temporarily disable a task:

1. Edit the crontab:
   ```bash
   sudo crontab -e
   ```

2. Comment out the relevant line by adding a `#` at the beginning:
   ```
   # 0 2 * * * /opt/agency_stack/scripts/cronjobs/health_check_cron.sh > /var/log/agency_stack/cron/health_check_cron.sh.log 2>&1
   ```

3. Save and exit the editor

## Adding Custom Tasks

To add a custom scheduled task:

1. Create a new script in `/opt/agency_stack/scripts/cronjobs/`
2. Make it executable: `chmod +x your_script.sh`
3. Add it to crontab: `sudo crontab -e`
4. Add a new line with your desired schedule:
   ```
   0 4 * * * /opt/agency_stack/scripts/cronjobs/your_script.sh > /var/log/agency_stack/cron/your_script.sh.log 2>&1
   ```

## Dashboard Integration

The AgencyStack dashboard's "Alerts & Logs" tab shows results and logs from scheduled tasks. Access it by:

1. Open the AgencyStack dashboard (`make dashboard-open`)
2. Click the "Alerts & Logs" tab in the navigation
3. Filter by the type of log you want to view

## Troubleshooting

### Scheduled Tasks Not Running

1. Check if cron is running: `systemctl status cron`
2. Verify task is in crontab: `sudo crontab -l | grep health`
3. Check for execution errors: `cat /var/log/agency_stack/cron/*.log`
4. Ensure scripts are executable: `ls -la /opt/agency_stack/scripts/cronjobs/`

### Log Files Missing

1. Ensure log directory exists: `sudo mkdir -p /var/log/agency_stack/cron`
2. Check permissions: `sudo chmod 755 /var/log/agency_stack/cron`
3. Run `make setup-log-rotation` to set up proper logging

## Related Commands

- `make setup-cronjobs` - Install all scheduled tasks
- `make log-summary` - Display summary of all task logs
- `make health-check` - Run a health check manually
- `make verify-backup` - Verify backups manually
- `make dashboard-update` - Update the dashboard manually
