# Traefik Best Practices for Docker Multi-Container Deployments
# Following AgencyStack Charter v1.0.3 Principles

## Overview

This document outlines the best practices for configuring Traefik with Docker for multi-container deployments like PeaceFestivalUSA WordPress, with specific considerations for WSL environments. These patterns adhere to the AgencyStack Charter v1.0.3 principles of "Repository as Source of Truth" and "Strict Containerization".

## Network Configuration

According to official Traefik documentation, containers should share a common network with Traefik:

```yaml
# Recommended network configuration
networks:
  traefik_network: {}  # Create a custom network

services:
  traefik:
    # ...
    networks:
      - traefik_network
  
  wordpress:
    # ...
    networks:
      - traefik_network
      - wordpress_network  # Additional network for WordPress-MariaDB
```

The network should be explicitly created and managed, rather than relying on Docker Compose's default networking.

## Container Exposure

Traefik should be configured to not expose containers by default, requiring explicit opt-in:

```yaml
services:
  traefik:
    # ...
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"  # Don't expose by default
```

Containers that should be exposed need to be explicitly labeled:

```yaml
services:
  wordpress:
    # ...
    labels:
      - "traefik.enable=true"  # Explicitly enable this container
```

## Host Rules

Host rules should be configured with proper domain names, including support for multiple domains and catch-all routes:

```yaml
services:
  wordpress:
    # ...
    labels:
      - "traefik.http.routers.wordpress.rule=Host(`peacefestivalusa.localhost`) || Host(`localhost`)"
```

## Port Detection

Traefik automatically detects ports from exposed container ports, but it's best to explicitly specify the port for clarity:

```yaml
services:
  wordpress:
    # ...
    labels:
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"
```

## WSL-Specific Considerations

For WSL environments, additional configurations are needed:

1. **Host network detection**: Ensure proper binding to all interfaces
2. **Windows host access**: Configure proper host entries in both WSL and Windows

```yaml
services:
  traefik:
    # ...
    command:
      - "--entryPoints.web.address=:80"  # Bind to all interfaces for WSL compatibility
```

## Implementation Template

Here's a complete docker-compose template that follows these best practices:

```yaml
version: "3.3"

networks:
  traefik_network:
    name: peacefestivalusa_traefik_network
  wordpress_network:
    name: peacefestivalusa_wordpress_network

services:
  traefik:
    image: "traefik:v2.10"
    container_name: "peacefestivalusa_traefik"
    command:
      - "--api.insecure=true"  # For development only
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entryPoints.web.address=:80"
      - "--log.level=INFO"
    ports:
      - "80:80"
      - "8080:8080"  # Dashboard
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    networks:
      - traefik_network

  wordpress:
    image: "wordpress:6.1-php8.1-apache"
    container_name: "peacefestivalusa_wordpress"
    environment:
      WORDPRESS_DB_HOST: mariadb
      WORDPRESS_DB_NAME: peacefestivalusa_wordpress
      WORDPRESS_DB_USER: peacefestivalusa_wp
      WORDPRESS_DB_PASSWORD: password123
    volumes:
      - "/opt/agency_stack/clients/peacefestivalusa/wordpress/wp-content:/var/www/html/wp-content"
    depends_on:
      - mariadb
    networks:
      - traefik_network
      - wordpress_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(`peacefestivalusa.localhost`) || Host(`localhost`)"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"

  mariadb:
    image: "mariadb:10.5"
    container_name: "peacefestivalusa_mariadb"
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: peacefestivalusa_wordpress
      MYSQL_USER: peacefestivalusa_wp
      MYSQL_PASSWORD: password123
    volumes:
      - "/opt/agency_stack/clients/peacefestivalusa/wordpress/db_data:/var/lib/mysql"
    networks:
      - wordpress_network
```

## Repository Structure

Following the AgencyStack Charter v1.0.3 principles, this implementation should be stored in:

1. Script: `/scripts/components/peacefestivalusa/install/traefik.sh`
2. Config templates: `/scripts/components/peacefestivalusa/templates/traefik-docker-compose.yml`
3. Documentation: `/docs/pages/components/peacefestivalusa-traefik.md`

## Windows Host Browser Access

For Windows host browser access in WSL environments:

1. Create host entries in Windows hosts file:
   ```
   127.0.0.1 peacefestivalusa.localhost
   127.0.0.1 traefik.peacefestivalusa.localhost
   ```

2. Use the WSL host IP as a fallback:
   ```bash
   WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
   echo "Windows Host IP: ${WINDOWS_HOST_IP}"
   ```

## Testing

Verify the setup with comprehensive tests:

```bash
# Test local access
curl -H "Host: peacefestivalusa.localhost" http://localhost

# Test Windows host access (WSL)
WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
curl -H "Host: peacefestivalusa.localhost" http://${WINDOWS_HOST_IP}
```
