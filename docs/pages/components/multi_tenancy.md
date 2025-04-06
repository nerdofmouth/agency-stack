# Multi-Tenancy

## Overview

The Multi-Tenancy component configures and manages client isolation in AgencyStack, enabling the hosting of services for multiple clients on the same infrastructure. It provides isolation at various levels, from shared services with separate data to fully isolated service stacks.

## Installation

```bash
# Standard installation
make multi_tenancy

# With custom options
make multi_tenancy CLIENT_ID=myagency DOMAIN=example.com ISOLATION_LEVEL=medium
```

## Configuration

The Multi-Tenancy component stores its configuration in:
- `/opt/agency_stack/multi_tenancy/` (global configuration)
- `/opt/agency_stack/clients/${CLIENT_ID}/multi_tenancy/` (client-specific configuration)

Key files:
- `config.yaml`: Main configuration file with isolation settings
- `clients.json`: Registry of all clients and their settings
- `scripts/`: Helper scripts for client management

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `--default-client-id` | Default client identifier | `default` |
| `--root-domain` | Root domain for subdomain creation | `localhost` |
| `--force` | Force reinstallation | `false` |
| `--isolation-level` | Level of client isolation | `medium` |
| `--clients` | Comma-separated list of clients to create | `default` |
| `--custom-config` | Path to custom configuration file | `""` |

### Isolation Levels

- **soft**: Shared services, client-specific data directories
- **medium**: Shared infrastructure, separate service instances
- **hard**: Fully isolated stacks with dedicated resources

## Restart and Maintenance

```bash
# Check status
make multi_tenancy-status

# View logs
make multi_tenancy-logs

# Restart related services
make multi_tenancy-restart
```

## Client Management

The Multi-Tenancy component provides scripts for client management:

```bash
# Add a new client
/opt/agency_stack/multi_tenancy/scripts/add_client.sh --client-id new_client --domain new-client.example.com

# Remove a client
/opt/agency_stack/multi_tenancy/scripts/remove_client.sh --client-id client_to_remove

# List all clients
/opt/agency_stack/multi_tenancy/scripts/list_clients.sh
```

## Security

The Multi-Tenancy component enhances security by:

- Isolating client data and configurations
- Creating client-specific network segments
- Providing subdomain separation
- Supporting client-specific SSL certificates
- Implementing access controls between client resources

## Troubleshooting

Common issues:

1. **Client Isolation Conflicts**
   - Check network segmentation configuration
   - Verify Docker network isolation
   - Review Traefik routing rules

2. **Subdomain Access Issues**
   - Verify DNS configuration
   - Check SSL certificate setup
   - Review client registration in multi_tenancy configuration

3. **Resource Contention**
   - Implement resource limits for containers
   - Consider using the 'hard' isolation level
   - Monitor shared resource usage
