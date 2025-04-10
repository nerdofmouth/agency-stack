# Bolt DIY

## Overview
Bolt DIY is a workflow automation platform that enables users to create and manage AI-driven workflows without extensive coding knowledge.

## Installation
```bash
make bolt-diy
```

### Options
- `--domain`: Domain name for the Bolt DIY instance
- `--admin-email`: Admin email for notifications
- `--client-id`: Client ID for multi-tenancy
- `--force`: Force reinstallation
- `--with-deps`: Install dependencies
- `--verbose`: Enable verbose output

## Management

### Check Status
```bash
make bolt-diy-status
```

### View Logs
```bash
make bolt-diy-logs
```

### Restart Service
```bash
make bolt-diy-restart
```

## Configuration

### Ports
- `8080`: Web interface

### Directories
- `/opt/agency_stack/clients/{CLIENT_ID}/bolt_diy`: Installation directory
- `/var/log/agency_stack/components/bolt_diy.log`: Log file

## Security
- Runs as dedicated `bolt-diy` system user
- Systemd service with restricted permissions
- Logs all installation and runtime activity

## Integration
- Can be integrated with Keycloak for authentication
- Exposes metrics endpoint for monitoring

## Troubleshooting
Check logs for errors:
```bash
tail -f /var/log/agency_stack/components/bolt_diy.log
```
