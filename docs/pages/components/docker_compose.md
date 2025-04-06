---
layout: default
title: Docker Compose - AgencyStack Documentation
---

# Docker Compose

## Overview

Docker Compose is the orchestration tool that coordinates multi-container applications within AgencyStack. It defines and runs multi-container Docker applications, allowing components to be easily deployed, updated, and managed as a unified service.

## Features

- **Service Definition**: Define multi-container applications in a single YAML file
- **Environment Isolation**: Run multiple environments from the same configuration
- **Dependency Resolution**: Automatically start containers in dependency order
- **Volume Sharing**: Manage persistent data across container restarts
- **Network Configuration**: Create isolated networks for components
- **Environment Variable Management**: Pass configuration via `.env` files
- **Scaling**: Run multiple instances of services as needed
- **Health Checks**: Monitor service health and restart failed containers

## Prerequisites

- Docker (installed automatically as dependency)
- Python 3+ (for Docker Compose V2)

## Installation

Docker Compose is installed automatically as part of the infrastructure when running:

```bash
make infrastructure
```

For manual installation:

```bash
make docker-compose
```

Options:
- `--force`: Override existing installation

## Configuration

Docker Compose configurations for AgencyStack components are stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/<component>/docker-compose.yml
```

Standard configuration includes:

- Service definitions with image, ports, volumes, and environment variables
- Network configuration (typically with Traefik integration)
- Volume mounts to persistent storage
- Health checks for service validation
- Resource limits for stability

## Usage

### Management Commands

```bash
# Check status
make docker-compose-status

# View Docker Compose version
docker-compose --version

# View a component's Docker Compose file
cat /opt/agency_stack/clients/${CLIENT_ID}/<component>/docker-compose.yml
```

### Using Compose Files

AgencyStack components use Docker Compose for deployment. While most operations should be performed through Makefile targets, direct Docker Compose commands can be used:

```bash
# Start services defined in a docker-compose.yml file
cd /path/to/docker-compose-directory && docker-compose up -d

# View logs for all services in a compose file
cd /path/to/docker-compose-directory && docker-compose logs

# Stop services defined in a docker-compose.yml file
cd /path/to/docker-compose-directory && docker-compose down
```

## Security

Docker Compose configurations in AgencyStack implement several security measures:

- No privileged modes unless absolutely necessary
- Resource limits for all containers (CPU, memory)
- Read-only file systems where possible
- Reduced container capabilities
- Non-root users inside containers
- Secure environment variable handling
- Isolation through dedicated networks

## Monitoring

Docker Compose operations are logged to:

```
/var/log/agency_stack/components/docker_compose.log
```

## Troubleshooting

### Common Issues

1. **Version incompatibility**:
   - Verify Docker Compose version compatibility with Docker version
   - Update both if necessary with `make docker` and `make docker-compose`

2. **Network conflicts**:
   - Ensure no conflicting networks between different compose files
   - Use the `docker network ls` command to check for duplicates

3. **Port conflicts**:
   - Check for port conflicts using `make detect-ports`
   - Resolve with `make remap-ports` or manual config adjustment

### Logs

For detailed logs:

```bash
# View Docker Compose command logs
tail -f /var/log/agency_stack/components/docker_compose.log

# View logs for specific services
docker-compose -f /path/to/docker-compose.yml logs [service_name]
```

## Integration with Other Components

Docker Compose integrates with:

1. **All AgencyStack components**: Most are deployed via Docker Compose
2. **Traefik**: For service discovery and routing
3. **Prometheus/Grafana**: For service monitoring
4. **Loki**: For log aggregation

## Advanced Customization

To customize Docker Compose behavior, edit:

```
/opt/agency_stack/config/docker/compose.yml
```

For client-specific customization, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/config/docker-compose-override.yml
```

## Multi-tenant Configuration

Docker Compose supports multi-tenant deployments through:

1. **Client-specific Compose files**: Stored in client directories
2. **Network Isolation**: Each client gets dedicated networks
3. **Volume Namespacing**: Client ID in volume names
4. **Environment Variables**: Client-specific configurations passed via environment
