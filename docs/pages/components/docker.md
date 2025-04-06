---
layout: default
title: Docker - AgencyStack Documentation
---

# Docker

## Overview

Docker is the container runtime engine that powers AgencyStack. It enables reliable, repeatable deployment of all components in isolated containers, ensuring consistency across environments and supporting the sovereign infrastructure model.

## Features

- **Container Management**: Run applications in isolated environments
- **Resource Control**: Limit CPU, memory, and other resources per container
- **Networking**: Isolated networks with controlled exposure of services
- **Image Management**: Version-controlled application images
- **Volume Management**: Persistent storage for container data
- **Security**: Container isolation and resource constraints
- **Multi-tenant Support**: Isolate clients through separate container networks

## Prerequisites

- Linux-based operating system (Debian/Ubuntu recommended)
- Root access for installation
- Ports 2375 and 2376 available (for Docker API, if enabled)

## Installation

Docker is installed automatically as part of the core infrastructure when running:

```bash
make infrastructure
```

For manual installation:

```bash
make docker
```

Options:
- `--force`: Override existing installation

## Configuration

Docker configuration is stored in:

```
/etc/docker/daemon.json
```

AgencyStack's Docker configuration sets:

- Default logging driver: json-file with rotation
- Default log limits: 100MB per container
- Live restore: enabled for resilience
- Default address pools for container networks
- User namespace remapping (when security level is set to high)

## Usage

### Management Commands

```bash
# Check status
make docker-status

# View logs
make docker-logs

# Restart service
make docker-restart
```

### Container Management

Docker provides the foundation for all AgencyStack components. While most container management should be done through the Makefile targets, direct Docker commands can be used:

```bash
# List running containers
docker ps

# View container logs
docker logs CONTAINER_ID

# Stop a container
docker stop CONTAINER_ID

# Remove a container
docker rm CONTAINER_ID
```

## Security

Docker is configured with the following security measures:

- Container limits: CPU, memory, and PID limits
- No privileged containers by default
- User namespace remapping (security level: high)
- No Docker socket exposure to containers by default
- Restricted syscall capabilities
- Regular security updates

## Monitoring

Docker logs are stored in:

```
/var/log/agency_stack/components/docker.log
```

Container metrics are exposed to Prometheus via Traefik metrics middleware or cAdvisor.

## Troubleshooting

### Common Issues

1. **Insufficient disk space**:
   - Clear unused images: `docker system prune`
   - Increase disk allocation for Docker storage
   - Check and rotate container logs

2. **Container fails to start**:
   - Check logs: `docker logs CONTAINER_ID`
   - Verify resource limits are appropriate
   - Check network configuration

3. **Permission issues**:
   - Verify Docker socket permissions
   - Check user group membership (docker group)
   - Verify volume mount permissions

### Logs

For detailed logs:

```bash
# Docker daemon logs
journalctl -u docker

# Component-specific logs
tail -f /var/log/agency_stack/components/docker.log
```

## Integration with Other Components

Docker is the foundational component for AgencyStack and integrates with:

1. **Traefik**: For service discovery and routing
2. **Portainer**: For web-based container management
3. **Prometheus/Grafana**: For container monitoring
4. **Loki**: For log aggregation
5. **All AgencyStack components**: All run as Docker containers

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/config/docker/daemon.json
```

## Multi-tenant Configuration

Docker supports multi-tenant deployments through:

1. **Isolated Networks**: Each client gets a dedicated Docker network
2. **Volume Isolation**: Client-specific persistent storage
3. **Resource Quotas**: Per-client resource limits
4. **Label-based Organization**: Client ID labels for tracking resources
