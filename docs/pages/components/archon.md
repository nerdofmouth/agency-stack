# Archon

## Overview
Archon is an AI agent orchestration platform that enables complex multi-agent workflows and coordination.

## Installation
```bash
make archon
```

### Options
- `--domain`: Domain name for the Archon instance
- `--admin-email`: Admin email for notifications
- `--client-id`: Client ID for multi-tenancy
- `--force`: Force reinstallation
- `--with-deps`: Install dependencies
- `--verbose`: Enable verbose output

## Management

### Check Status
```bash
make archon-status
```

### View Logs
```bash
make archon-logs
```

### Restart Service
```bash
make archon-restart
```

## Configuration

### Ports
- `8080`: Web interface
- `5000`: API endpoint

### Directories
- `/opt/agency_stack/clients/{CLIENT_ID}/archon`: Installation directory
- `/var/log/agency_stack/components/archon.log`: Log file

## Security
- Runs in isolated Docker container
- Environment variables for sensitive configuration
- Logs all installation and runtime activity

## Integration
- Can be integrated with Keycloak for authentication
- Exposes Prometheus metrics endpoint
- Supports webhook notifications

## Troubleshooting
Check logs for errors:
```bash
tail -f /var/log/agency_stack/components/archon.log
```

Check container status:
```bash
docker ps -f name=archon
```
