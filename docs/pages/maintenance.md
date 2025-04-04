---
layout: default
title: Maintenance and Backup - AgencyStack Documentation
---

# Maintenance and Backup

Proper maintenance ensures your AgencyStack installation remains reliable and secure. This guide covers routine maintenance tasks, backup procedures, and update methods.

## Routine Maintenance

### System Health Check

Run a comprehensive system health check with:

```bash
cd /opt/agency_stack
make test-env
```

This checks:
- All required services are running
- Network connectivity
- Storage capacity
- Memory usage
- Security configuration

We recommend running this weekly or after any system changes.

### Container Updates

Update all containers to their latest versions:

```bash
cd /opt/agency_stack
make update
```

### OS Updates

Keep your host system updated:

```bash
apt update && apt upgrade -y
```

Consider using unattended-upgrades for automatic security updates.

## Backup Procedures

### Full System Backup

Create a complete backup of the AgencyStack installation:

```bash
cd /opt/agency_stack
make backup
```

This creates a timestamped backup in `/opt/agency_stack/backups/`.

### Individual Client Backup

Backup a specific client's data:

```bash
cd /opt/agency_stack
./scripts/backup_client.sh client.domain.com
```

### Automated Backups

Set up automated daily backups with:

```bash
cd /opt/agency_stack
./scripts/setup_automated_backups.sh
```

This configures a cron job to perform daily backups at 2 AM.

## Restoring from Backup

### Full System Restore

To restore from a full system backup:

```bash
cd /opt/agency_stack
./scripts/restore.sh /path/to/backup.tar.gz
```

### Individual Client Restore

Restore a specific client:

```bash
cd /opt/agency_stack
./scripts/restore_client.sh client.domain.com /path/to/client-backup.tar.gz
```

## Log Management

### Viewing Logs

View logs for all services:

```bash
cd /opt/agency_stack
make logs
```

For client-specific logs:

```bash
cd /opt/agency_stack/clients/client.domain.com
docker-compose logs
```

### Log Rotation

AgencyStack configures automatic log rotation. Configure advanced settings in:

```
/opt/agency_stack/config/logging/logrotate.conf
```

## Database Maintenance

### Database Backups

Each service's database is backed up as part of the regular backup procedure. For manual database backups:

```bash
cd /opt/agency_stack
./scripts/backup_databases.sh
```

### Database Optimization

For larger installations, consider running database optimization routines:

```bash
cd /opt/agency_stack
./scripts/optimize_databases.sh
```

## Security Maintenance

### SSL Certificate Renewal

Traefik automatically handles Let's Encrypt SSL certificate renewal. To force renewal:

```bash
cd /opt/agency_stack
./scripts/renew_certificates.sh
```

### Security Audit

Run a security audit with:

```bash
cd /opt/agency_stack
make security-check
```

This checks for:
- Outdated containers
- Exposed ports
- Weak configurations
- Known vulnerabilities

## Performance Tuning

View current system performance:

```bash
cd /opt/agency_stack
make rootofmouth
```

For performance optimization tips, see our [Performance Tuning Guide](performance-tuning.html).

## Troubleshooting

If you encounter issues during maintenance:

1. Check the logs in `/var/log/agency_stack/`
2. Run the environment test: `make test-env`
3. View container status: `docker ps -a`
4. Consult our [Troubleshooting Guide](troubleshooting.html)

For persistent issues, contact [support@nerdofmouth.com](mailto:support@nerdofmouth.com).
