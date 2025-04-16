# Backup Strategy

## Overview
The Backup Strategy component provides a robust, encrypted, incremental backup solution for AgencyStack using Restic. It ensures that critical data is securely backed up, with support for multiple storage backends including local storage, SFTP, S3, and Backblaze B2.

## Features
- End-to-end encryption of all backups
- Incremental backups to minimize storage and bandwidth
- Multiple storage backends supported
- Configurable retention policies
- Scheduled automatic backups
- Email notifications for backup status
- Verification and integrity checking

## Installation

```bash
# Standard installation
make backup-strategy DOMAIN=example.com ADMIN_EMAIL=admin@example.com

# Multi-tenant installation
make backup-strategy DOMAIN=example.com ADMIN_EMAIL=admin@example.com CLIENT_ID=client1
```

## Paths and Locations

| Path | Description |
|------|-------------|
| `/opt/agency_stack/clients/<client_id>/backup_strategy` | Main installation directory |
| `/opt/agency_stack/clients/<client_id>/backup_strategy/scripts` | Backup and restore scripts |
| `/opt/agency_stack/clients/<client_id>/backup_strategy/logs` | Backup operation logs |
| `/opt/agency_stack/clients/<client_id>/backup_strategy/env` | Environment configuration |
| `/opt/agency_stack/secrets/backup_strategy/<client_id>` | Secure storage for encryption passwords |
| `/var/log/agency_stack/components/backup_strategy.log` | Component installation log |
| `/etc/cron.d/agency-stack-backup-<client_id>` | Cron job configuration |

## Configuration

The primary configuration file is located at `/opt/agency_stack/clients/<client_id>/backup_strategy/env/restic.env`. This file contains:

- Backend configuration (Local, SFTP, S3, B2, etc.)
- Encryption password
- Retention policy settings
- Backup paths and exclusions
- Email notification settings

Example configuration:

```bash
# S3 backend (AWS, MinIO, etc.)
RESTIC_REPOSITORY=s3:s3.amazonaws.com/bucket_name/path
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

# Encryption password
RESTIC_PASSWORD=your_secure_password

# Retention policy
RETENTION_DAYS=7
RETENTION_WEEKS=4
RETENTION_MONTHS=12

# Backup paths (comma-separated)
BACKUP_PATHS=/opt/agency_stack/clients/client1,/var/log/agency_stack/clients/client1

# Exclude patterns (comma-separated)
EXCLUDE_PATTERNS=**/.git,**/node_modules,**/tmp,**/temp,**/cache

# Email notification
NOTIFICATION_EMAIL=admin@example.com
```

## Logs

Logs are stored in two locations:

1. Installation logs: `/var/log/agency_stack/components/backup_strategy.log`
2. Backup operation logs: `/opt/agency_stack/clients/<client_id>/backup_strategy/logs/backup_YYYY-MM-DD_HH-MM-SS.log`

To view logs:

```bash
# View installation logs
cat /var/log/agency_stack/components/backup_strategy.log

# View backup operation logs through Makefile
make backup-strategy-logs CLIENT_ID=client1
```

## Ports
This component does not use any network ports directly. Communication with remote storage providers is done using standard protocols like HTTPS, SSH, etc.

## Management

The following Makefile targets are available:

```bash
# Install the component
make backup-strategy

# Check status
make backup-strategy-status

# View logs
make backup-strategy-logs

# Run a backup immediately
make backup-strategy-restart
```

## Manual Operations

For manual backup and restore operations:

```bash
# Run a backup manually
sudo /opt/agency_stack/clients/<client_id>/backup_strategy/scripts/backup.sh

# Restore from backup
sudo /opt/agency_stack/clients/<client_id>/backup_strategy/scripts/restore.sh --target /path/to/restore
```

## Security Considerations

- The encryption password is stored in `/opt/agency_stack/secrets/backup_strategy/<client_id>/restic_password.txt`
- This file has restricted permissions (600) and should be backed up separately
- Loss of the encryption password will make the backups unrecoverable
- The environment file containing credentials has restricted permissions (600)
- Consider using IAM roles with limited permissions when using cloud storage backends

## Integration with Other Components

The Backup Strategy component can back up data from any other AgencyStack component by specifying their data directories in the configuration. Critical components to consider backing up include:

- Keycloak (identity management data)
- Databases (PostgreSQL, MySQL, etc.)
- Document storage (Seafile, etc.)
- Configuration files and environment variables

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Backup fails with permission errors | Ensure the backup script runs as root via sudo |
| Connection errors to remote storage | Check network connectivity and credentials |
| Out of disk space errors | Adjust retention policy or add more storage |
| Slow backups | Consider excluding large, frequently changing files that aren't critical |
| Repository lock errors | Remove stale locks with `restic unlock` |
