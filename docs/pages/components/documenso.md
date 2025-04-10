# Documenso

## Overview
Document signing platform

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_documenso.sh` script, which can be executed using:

```bash
make documenso
```

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/documenso.log`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Upgrading to v1.4.2

### Prerequisites
- Backup your database and document storage
- Ensure you have at least 1GB free disk space

### Upgrade Process
```bash
# Standard upgrade
make documenso-upgrade

# Force upgrade (if needed)
make documenso-upgrade FORCE=true
```

### Key Features in v1.4.2
- Enhanced Keycloak SSO integration
- Improved multi-tenant support
- Better document template management
- Performance optimizations for large documents

### Post-Upgrade Checks
1. Verify all documents are accessible:
```bash
make documenso-status
```
2. Check migration logs:
```bash
make documenso-logs | grep -i migration
```

### Rollback Procedure
If issues occur:
```bash
# Stop service
make documenso-stop

# Restore from backup
cp -r /opt/agency_stack/clients/{CLIENT_ID}/documenso_backup_*/* /opt/agency_stack/clients/{CLIENT_ID}/documenso/

# Restart previous version
make documenso-start
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make documenso` | Install documenso |
| `make documenso-status` | Check status of documenso |
| `make documenso-logs` | View documenso logs |
| `make documenso-restart` | Restart documenso services |
| `make documenso-upgrade` | Upgrade documenso |
