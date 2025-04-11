# Traefik Container Network Mode

This document explains the network configuration options for the Traefik reverse proxy in AgencyStack.

## Overview

Traefik can be configured to use different Docker network modes, which affects how it communicates with other services:

1. **Host Network Mode** (Default): Traefik shares the host's network stack, allowing direct communication with services on the host
2. **Bridge Network Mode**: Traefik uses Docker's bridge network, requiring explicit port mapping and service URLs with host IP

## Configuration Options

### Host Network Mode (Recommended)

Using host network mode simplifies container-to-host communication, which is critical for proper FQDN access to services running on the host (like the dashboard). This mode is enabled by default.

```bash
# Installation with explicit host network mode
make traefik DOMAIN=your-domain.com --use-host-network=true
```

### Bridge Network Mode

Bridge mode requires specific host IP configuration for container-to-host communication:

```bash
# Installation with bridge network mode
make traefik DOMAIN=your-domain.com --use-host-network=false
```

## Troubleshooting FQDN Access Issues

If you encounter "Bad Gateway" errors when accessing services via FQDN:

1. **Check Network Mode**: Verify that Traefik is configured with the appropriate network mode
   ```
   grep "network_mode" /opt/agency_stack/clients/default/traefik/docker-compose.yml
   ```

2. **Verify Service URL Configuration**: Check that the dashboard-route.yml contains the correct URL format
   ```
   cat /opt/agency_stack/clients/default/traefik/config/dynamic/dashboard-route.yml
   ```

3. **Adjust Configuration if Needed**:
   - For host network mode: services should use `http://localhost:<PORT>`
   - For bridge network mode: services should use `http://<HOST_IP>:<PORT>`

## Coordinating Network Mode Across Components

For proper operation, ensure all components use the same network mode settings:

```bash
# Example: Using host network mode across all components
make traefik DOMAIN=your-domain.com --use-host-network=true
make dashboard DOMAIN=your-domain.com --use-host-network=true
```

## Technical Details

Host network mode resolves the container network isolation issue where a containerized Traefik cannot reach services on the host machine via `localhost`. When a Docker container uses `localhost`, it refers to the container itself, not the host machine.
