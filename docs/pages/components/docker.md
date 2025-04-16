# Docker

## Overview
The Docker component provides container runtime capabilities for AgencyStack, enabling isolated deployment of services with proper resource management and networking. It serves as a foundational infrastructure component required by most other AgencyStack components.

## Features
- Isolated container runtime for services
- Shared Docker network for inter-service communication
- Optimized default configuration for production environments
- Resource limitations and logging controls
- Support for multi-tenant deployments
- Security hardening

## Installation

```bash
# Standard installation
make docker

# Force reinstallation
make docker FORCE=true

# Installation with specific version
make docker VERSION=20.10.22
```

## Paths and Locations

| Path | Description |
|------|-------------|
| `/opt/agency_stack/docker` | Main installation directory |
| `/opt/agency_stack/docker/version.txt` | Installed Docker version information |
| `/opt/agency_stack/docker/docker_info.txt` | Docker system information |
| `/etc/docker/daemon.json` | Docker daemon configuration |
| `/var/log/agency_stack/components/docker.log` | Component installation log |
| `/var/lib/docker` | Docker data directory (images, containers, volumes) |

## Configuration

The Docker daemon is configured with production-grade defaults in `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 32768
    }
  }
}
```

Key configuration elements:
- **Log rotation**: 100MB maximum file size with 5 rotations
- **Storage driver**: overlay2 for optimal performance
- **Live restore**: allows containers to continue running during daemon restarts
- **File limits**: 65536 open files limit for container processes

## Logs

Docker logs can be found in two locations:

1. Installation logs: `/var/log/agency_stack/components/docker.log`
2. Docker daemon logs: available via `journalctl -u docker`

To view logs:

```bash
# View installation logs through Makefile
make docker-logs

# View system Docker logs
journalctl -u docker
```

## Ports

Docker uses the following ports by default:

| Port | Protocol | Purpose |
|------|----------|---------|
| 2375 | TCP | Docker daemon API (only available on localhost) |
| 2376 | TCP | Docker daemon API (TLS, when configured) |

Additionally, various containers may expose their own ports as required.

## Management

The following Makefile targets are available:

```bash
# Install Docker
make docker

# Check Docker status
make docker-status

# View Docker logs
make docker-logs

# Restart Docker service
make docker-restart
```

Common Docker commands:

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# List images
docker images

# View container logs
docker logs CONTAINER_NAME

# Execute command in container
docker exec -it CONTAINER_NAME COMMAND
```

## Docker Networks

The AgencyStack uses a dedicated Docker network for container communication:

```
agency_stack_network
```

This network is created during Docker installation and should be used by all AgencyStack components when defining Docker Compose services.

## Security Considerations

- The Docker daemon runs with root privileges, so access to the Docker socket implies root-level access
- Only users in the `docker` group can control Docker
- Use caution when exposing container ports to the internet
- Consider implementing Docker content trust for image verification
- Regularly update Docker to address security vulnerabilities
- Implement resource limits for containers to prevent denial-of-service

## Integration with Other Components

Docker is a foundational component used by virtually all other AgencyStack components that utilize containerization, including:

- Keycloak
- Grafana
- Loki
- Traefik
- PeerTube
- Mailu
- All other containerized services

## Usage

### Basic Docker Commands

Manage containers, images, and Docker resources:

```bash
# View running containers
docker ps

# View all containers (including stopped)
docker ps -a

# Pull an image
docker pull ubuntu:latest

# Run a container
docker run -d --name my_container ubuntu:latest sleep infinity

# Stop a container
docker stop my_container

# Remove a container
docker rm my_container

# View images
docker images

# Remove an image
docker rmi ubuntu:latest
```

### Working with Docker Networks

Create and manage container networks:

```bash
# List networks
docker network ls

# Create a network
docker network create my_network

# Run container on a specific network
docker run -d --network my_network --name networked_container nginx

# Connect existing container to network
docker network connect my_network existing_container

# Inspect network
docker network inspect my_network
```

### Docker Volumes for Persistent Storage

Manage persistent data with volumes:

```bash
# Create a volume
docker volume create my_volume

# List volumes
docker volume ls

# Run container with volume
docker run -d -v my_volume:/data --name data_container ubuntu

# Backup a volume
docker run --rm -v my_volume:/source -v $(pwd):/backup ubuntu tar cvf /backup/volume_backup.tar /source

# Restore a volume
docker run --rm -v my_volume:/target -v $(pwd):/backup ubuntu tar xvf /backup/volume_backup.tar -C /
```

### Docker Compose

Use Docker Compose for multi-container applications:

```bash
# Start services defined in docker-compose.yml
docker-compose up -d

# View running services
docker-compose ps

# View logs
docker-compose logs

# Stop services
docker-compose down

# Rebuild and restart services
docker-compose up -d --build
```

### Resource Monitoring

Monitor Docker resource usage:

```bash
# View container statistics
docker stats

# Show disk usage
docker system df

# View container logs
docker logs container_name

# Follow logs in real-time
docker logs -f container_name
```

### Docker System Maintenance

Perform system maintenance tasks:

```bash
# Remove unused containers, networks, images
docker system prune

# Remove all unused volumes
docker system prune --volumes

# View Docker info
docker info

# Check Docker service status
systemctl status docker

# Restart Docker service
sudo systemctl restart docker
```

### Multi-tenant Usage with AgencyStack

When working in a multi-tenant environment:

```bash
# Use client-specific networks
docker network create ${CLIENT_ID}_network

# Run client-specific containers
docker run -d --name ${CLIENT_ID}_app --network ${CLIENT_ID}_network app_image

# Use client-specific volume names
docker volume create ${CLIENT_ID}_data
```

## Ports & Endpoints

Docker uses the following ports by default:

| Port | Protocol | Purpose |
|------|----------|---------|
| 2375 | TCP | Docker daemon API (only available on localhost) |
| 2376 | TCP | Docker daemon API (TLS, when configured) |

Additionally, various containers may expose their own ports as required.

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Docker daemon won't start | Check logs with `journalctl -u docker` |
| Permission denied | Ensure user is in the docker group and has logged out/in |
| No space left on device | Clean up unused images with `docker system prune` |
| Network conflicts | Check for overlapping network subnets in Docker networks |
| Container won't start | Check container logs with `docker logs CONTAINER_NAME` |
| Docker network issues | Try recreating the network with `docker network create agency_stack_network` |
