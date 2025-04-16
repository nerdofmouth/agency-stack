# Docker Compose

## Overview
Docker Compose is a tool for defining and running multi-container Docker applications. It uses YAML files to configure application services and performs the creation and start-up of all the containers with a single command. In AgencyStack, Docker Compose is used to orchestrate and manage the various containerized services.

## Features
- Multi-container orchestration
- Declarative application definition
- Environment variable management
- Volume and networking configuration
- Service dependency management
- Container lifecycle control

## Installation

```bash
# Standard installation
make docker-compose

# Force reinstallation
make docker-compose FORCE=true

# Installation with specific version
make docker-compose VERSION=2.17.2

# Install with Docker dependency if needed
make docker-compose WITH_DEPS=true
```

## Paths and Locations

| Path | Description |
|------|-------------|
| `/opt/agency_stack/docker_compose` | Main installation directory |
| `/opt/agency_stack/docker_compose/version.txt` | Installed Docker Compose version information |
| `/opt/agency_stack/clients/<client_id>/docker_compose` | Client-specific Docker Compose files |
| `/opt/agency_stack/clients/<client_id>/docker_compose/test-docker-compose.sh` | Test script for Docker Compose |
| `/usr/local/bin/docker-compose` | Docker Compose binary |
| `/var/log/agency_stack/components/docker_compose.log` | Component installation log |

## Configuration

Docker Compose does not require specific configuration after installation. Each AgencyStack component that uses Docker Compose will create its own `docker-compose.yml` file in its installation directory.

A typical Docker Compose file structure in AgencyStack follows this pattern:

```yaml
version: '3'

services:
  service-name:
    image: image-name:tag
    container_name: container-name
    restart: unless-stopped
    environment:
      - KEY=value
    volumes:
      - /path/on/host:/path/in/container
    networks:
      - agency_stack_network

networks:
  agency_stack_network:
    external: true
```

Key configuration elements:
- **Version**: Typically version 3 or higher 
- **Services**: Individual containers, their images, and configuration
- **Networks**: Using the shared `agency_stack_network` for inter-service communication
- **Volumes**: Persistent data storage
- **Environment variables**: Configuration parameters

## Logs

Docker Compose logs can be found in:

```bash
# Installation logs
/var/log/agency_stack/components/docker_compose.log

# Service-specific logs
docker-compose logs service-name
```

To view installation logs:

```bash
# View Docker Compose installation logs through Makefile
make docker-compose-logs
```

## Ports

Docker Compose itself does not use any specific ports, but it manages port exposure for the containers it orchestrates. Each service can specify port mappings in its Docker Compose file:

```yaml
services:
  web:
    ports:
      - "8080:80"  # Maps host port 8080 to container port 80
```

## Management

The following Makefile targets are available:

```bash
# Install Docker Compose
make docker-compose

# Check Docker Compose status
make docker-compose-status

# View installation logs
make docker-compose-logs

# Test Docker Compose functionality
make docker-compose-restart
```

Common Docker Compose commands:

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View service logs
docker-compose logs [service]

# Check service status
docker-compose ps

# Execute command in container
docker-compose exec service-name command
```

## Using Docker Compose in AgencyStack Components

When creating new AgencyStack components that require Docker containers, follow these guidelines:

1. Store Docker Compose files in the component's installation directory
2. Use `agency_stack_network` for inter-service networking
3. Configure services to restart automatically with `restart: unless-stopped`
4. Use environment variables for configuration
5. Store persistent data in appropriate volume locations

Example Docker Compose file structure for a new component:

```yaml
version: '3'

services:
  new-component:
    image: example/image:latest
    container_name: new-component-${CLIENT_ID}
    restart: unless-stopped
    environment:
      - DOMAIN=${DOMAIN}
      - CLIENT_ID=${CLIENT_ID}
    volumes:
      - /opt/agency_stack/clients/${CLIENT_ID}/new-component/data:/data
    networks:
      - agency_stack_network

networks:
  agency_stack_network:
    external: true
```

## Security Considerations

- Avoid hardcoding secrets in Docker Compose files
- Use environment variables or Docker secrets for sensitive information
- Limit container capabilities to only what is needed
- Use host path volume mounts with caution
- Specify image versions explicitly, avoid using `:latest` in production

## Integration with Other Components

Docker Compose is a foundational component used by virtually all other AgencyStack components that utilize containerization, including:

- Keycloak
- Grafana
- Loki
- Traefik
- PeerTube
- Mailu
- All other containerized services

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Network not found | Ensure `agency_stack_network` exists: `docker network create agency_stack_network` |
| Container dependencies | Use `depends_on` to specify service dependencies |
| Environment variables not set | Check if variables are properly set in the environment or `.env` file |
| Port conflicts | Check for port conflicts with `netstat -tuln` |
| Volumes not accessible | Check permissions on host volume paths |
| Version compatibility | Ensure Docker Engine and Docker Compose versions are compatible |
