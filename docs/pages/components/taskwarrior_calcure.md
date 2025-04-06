# TaskWarrior & Calcurse

## Overview

The TaskWarrior & Calcurse component provides task management and calendar functionality for AgencyStack users. It combines TaskWarrior for task tracking and Calcurse for calendar management, with an optional web UI for easy access.

## Installation

```bash
# Standard installation
make taskwarrior_calcure

# With custom options
make taskwarrior_calcure CLIENT_ID=myagency DOMAIN=example.com WEB_PORT=8080
```

## Configuration

The TaskWarrior & Calcurse component stores its configuration in:
- `/opt/agency_stack/clients/${CLIENT_ID}/taskwarrior_calcure/`

Key directories and files:
- `taskwarrior/`: TaskWarrior configuration files
  - `taskrc`: Main TaskWarrior configuration file
- `calcurse/`: Calcurse configuration files
  - `conf`: Main Calcurse configuration file
  - `apts/`: Calendar appointments
- `data/`: Shared data directory
- `web/`: Web UI configuration (if enabled)
  - `config.json`: Web UI settings

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `--client-id` | Client identifier | `default` |
| `--domain` | Domain for web UI access | `localhost` |
| `--force` | Force reinstallation | `false` |
| `--no-web-ui` | Disable web UI | `false` |
| `--web-port` | Web UI port | `8080` |
| `--sync-enabled` | Enable TaskWarrior sync | `false` |
| `--custom-config` | Path to custom configuration file | `""` |

## Ports

| Port | Service | Notes |
|------|---------|-------|
| 8080 | TaskWarrior Web UI | Optional, provides web interface for task management |

## Restart and Maintenance

```bash
# Check status
make taskwarrior_calcure-status

# View logs
make taskwarrior_calcure-logs

# Restart services
make taskwarrior_calcure-restart
```

## Usage

### TaskWarrior CLI

```bash
# Add a new task
task add "Complete documentation for AgencyStack"

# List pending tasks
task next

# Mark task as done
task 1 done

# View task details
task 1 info
```

### Calcurse CLI

```bash
# Start Calcurse interface
calcurse

# Add appointment via CLI
calcurse --add-appointment "2023-12-25 @ 10:00 -> 11:00 | Christmas meeting"
```

### Web UI

If the web UI is enabled, it can be accessed at:
- `http://localhost:8080` (default)
- `http://taskwarrior.${CLIENT_ID}.${DOMAIN}` (with domain configuration)

## Security

The TaskWarrior & Calcurse component:

- Isolates task and calendar data per client
- Secures web UI access with authentication
- Supports encrypted task synchronization
- Provides Docker containerization for enhanced isolation
- Integrates with Traefik for HTTPS access

## Troubleshooting

Common issues:

1. **Web UI Access Issues**
   - Verify the service is running with `make taskwarrior_calcure-status`
   - Check firewall rules for web port access
   - Review authentication configuration

2. **Task Sync Problems**
   - Verify sync server configuration
   - Check network connectivity
   - Ensure proper certificate setup

3. **Data Persistence**
   - Verify data directory permissions
   - Check Docker volume configuration
   - Ensure data directory is backed up regularly
