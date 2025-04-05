---
layout: default
title: Drone CI - Continuous Integration Platform - AgencyStack Documentation
---

# Drone CI

Drone CI is a self-service Continuous Integration platform built on container technology, providing a powerful automation server for software teams.

![Drone CI Logo](https://drone.io/images/drone-logo.svg)

## Overview

Drone CI provides modern continuous integration and continuous delivery (CI/CD) through a powerful pipeline engine. This integration in AgencyStack offers a fully-featured CI/CD platform with multi-tenancy support, Gitea integration, and hardened security settings.

* **Version**: 2.16.0 (Server) / 1.8.0 (Runner)
* **Category**: DevOps
* **Website**: [https://drone.io](https://drone.io)
* **Github**: [https://github.com/harness/drone](https://github.com/harness/drone)

## Architecture

Drone CI in AgencyStack is composed of several components:

1. **Drone Server**: Central component that manages repositories, users, and events
2. **Drone Runner**: Executes pipeline steps in isolated Docker containers
3. **Redis**: Cache for server-side data
4. **SQLite**: Database for storing configuration and state information

## Features

* **Container-Native**: All pipeline steps run in Docker containers
* **Multi-Tenancy**: Separate instances for different clients with isolated storage
* **GitOps Workflow**: Pipelines defined as code in `.drone.yml` files
* **Gitea Integration**: Seamless connection to the AgencyStack Gitea service
* **Extensible**: Supports plugins, custom environments, and secrets
* **Scalable**: Multiple runners can be added as needed
* **Self-Healing**: Automatic recovery from failures
* **SSO Support**: Keycloak integration for centralized authentication
* **Prometheus Metrics**: Comprehensive monitoring integration

## Installation

### Prerequisites

* Docker and Docker Compose installed
* Traefik configured as reverse proxy
* Subdomain configured in DNS (e.g., `ci.example.com`)
* Mailu for SMTP notifications (optional)
* Gitea for repository management (optional)

### Using the Makefile

The simplest way to install Drone CI is through the AgencyStack Makefile:

```bash
# Set your domain and install
export DRONECI_DOMAIN=ci.example.com
make droneci

# For multi-tenant installations with a specific client ID
export DRONECI_DOMAIN=ci.client1.com
export CLIENT_ID=client1
make droneci

# With Gitea integration
export DRONECI_DOMAIN=ci.client1.com
export CLIENT_ID=client1
make droneci INSTALL_FLAGS="--enable-gitea --gitea-domain git.client1.com --gitea-client-id your_client_id --gitea-client-secret your_client_secret"
```

### Manual Installation

You can also install Drone CI manually using the installation script:

```bash
# Basic installation
sudo /opt/agency_stack/scripts/components/install_droneci.sh --domain ci.example.com

# Advanced installation with all options
sudo /opt/agency_stack/scripts/components/install_droneci.sh \
  --domain ci.client1.com \
  --client-id client1 \
  --enable-gitea \
  --gitea-domain git.client1.com \
  --gitea-client-id your_client_id \
  --gitea-client-secret your_client_secret \
  --enable-sso \
  --mailu-domain mail.client1.com \
  --mailu-user droneci@client1.com \
  --mailu-password your_secure_password \
  --drone-rpc-secret your_custom_rpc_secret \
  --with-deps \
  --force
```

## Management Commands

AgencyStack provides several commands to manage your Drone CI installation:

```bash
# Check status
make droneci-status

# View logs for server
make droneci-logs

# View logs for runner
make droneci-runner-logs

# Start/stop/restart services
make droneci-start
make droneci-stop
make droneci-restart

# Backup data
make droneci-backup

# Access configuration
make droneci-config
```

## Configuration

### Main Configuration

The main configuration for Drone CI is stored in the environment file at:

```
/opt/agency_stack/docker/droneci/.env
```

You can edit this file directly or use the Makefile command:

```bash
make droneci-config
```

### Gitea Integration

If you've enabled Gitea integration during installation, you'll need to complete the OAuth setup in Gitea:

1. Log in to Gitea as an administrator
2. Go to Site Administration > Applications
3. Create a new OAuth2 application:
   - Name: Drone CI
   - Redirect URI: https://your-drone-domain/login
   - Generate a Client ID and Client Secret
4. Update your Drone CI .env file with these credentials

Detailed instructions are provided in:
```
/opt/agency_stack/clients/{CLIENT_ID}/droneci_data/config/gitea/gitea-setup-instructions.txt
```

### Keycloak SSO Integration

If you've enabled SSO integration during installation, you'll need to complete the Keycloak setup:

1. Create a new client in your Keycloak realm:
   - Client ID: droneci
   - Client Protocol: openid-connect
   - Access Type: confidential
   - Valid Redirect URIs: https://your-drone-domain/login
2. Get the client secret from the Credentials tab
3. Update your Drone CI .env file with this secret

Detailed instructions are provided in:
```
/opt/agency_stack/clients/{CLIENT_ID}/droneci_data/config/sso/keycloak-setup-instructions.txt
```

## Security & Hardening

The AgencyStack Drone CI installation includes several security enhancements:

* **TLS Encryption**: All traffic is encrypted via Traefik's Let's Encrypt integration
* **Security Headers**: HTTP security headers to prevent XSS, clickjacking, and other attacks
* **Network Isolation**: Docker networks isolate the application components
* **Secret Management**: Secure storage of secrets and credentials
* **Minimal Permissions**: All containers run with minimal required permissions
* **Secure Cookies**: Cookies are set with secure flags and same-site restrictions
* **RPC Secret**: Secure communication between server and runners

## Data Location

Drone CI data is stored in the following locations:

* **Server Data**: `/opt/agency_stack/clients/{CLIENT_ID}/droneci_data/server/`
* **Runner Data**: `/opt/agency_stack/clients/{CLIENT_ID}/droneci_data/runner/`
* **Configuration**: `/opt/agency_stack/clients/{CLIENT_ID}/droneci_data/config/`

## Logs

Logs are available in the following locations:

* **Installation Logs**: `/var/log/agency_stack/components/droneci.log`
* **Server Logs**: Available via `make droneci-logs`
* **Runner Logs**: Available via `make droneci-runner-logs`

## Ports

| Service | Port | Protocol | Notes |
|---------|------|----------|-------|
| Drone Server | 3001 | HTTP | Web UI for Drone CI |
| Drone RPC | 3002 | HTTP | Server-Runner communication |
| Drone Runner | 3003 | HTTP | Runner API for health checks |

## Monitoring

Drone CI exposes Prometheus metrics at the `/metrics` endpoint for both the server and runner components. These metrics are automatically scraped by the AgencyStack monitoring system.

Health checks are configured for all containers, and a dedicated monitoring script is installed at:

```
/opt/agency_stack/monitoring/scripts/check_droneci-{CLIENT_ID}.sh
```

## Backup and Restore

### Backup

To backup your Drone CI data:

```bash
make droneci-backup
```

This creates a backup of the server data, runner data, and configuration files in the `/opt/agency_stack/backups/droneci/` directory.

### Restore

Restoring from a backup requires manual steps:

1. Stop the Drone CI services:
   ```bash
   make droneci-stop
   ```

2. Restore the data:
   ```bash
   # Replace with your actual backup files
   sudo tar -xzf /opt/agency_stack/backups/droneci/drone-server-{CLIENT_ID}-{TIMESTAMP}.tar.gz -C /opt/agency_stack/clients/{CLIENT_ID}/droneci_data
   sudo tar -xzf /opt/agency_stack/backups/droneci/drone-runner-{CLIENT_ID}-{TIMESTAMP}.tar.gz -C /opt/agency_stack/clients/{CLIENT_ID}/droneci_data
   sudo cp /opt/agency_stack/backups/droneci/drone-env-{CLIENT_ID}-{TIMESTAMP}.env /opt/agency_stack/docker/droneci/.env
   ```

3. Start the services:
   ```bash
   make droneci-start
   ```

## Adding Additional Runners

To add additional runners to your Drone CI installation:

1. Create a new runner configuration:
   ```bash
   sudo mkdir -p /opt/agency_stack/docker/droneci-runner2
   ```

2. Create a docker-compose.yml file for the new runner:
   ```yaml
   version: '3'
   
   services:
     drone-runner:
       image: drone/drone-runner-docker:1.8.0
       container_name: drone-runner2-{CLIENT_ID}
       restart: unless-stopped
       volumes:
         - /var/run/docker.sock:/var/run/docker.sock
       environment:
         - DRONE_RPC_SECRET={YOUR_RPC_SECRET}
         - DRONE_RPC_HOST={YOUR_DRONE_DOMAIN}
         - DRONE_RPC_PROTO=https
         - DRONE_RUNNER_NAME=drone-runner2-{CLIENT_ID}
         - DRONE_RUNNER_CAPACITY=2
       ports:
         - "3004:3000"  # Use a different port for each runner
       healthcheck:
         test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/healthz"]
         interval: 30s
         timeout: 5s
         retries: 3
   
   networks:
     default:
       external:
         name: droneci_network
   ```

3. Start the new runner:
   ```bash
   cd /opt/agency_stack/docker/droneci-runner2
   docker-compose up -d
   ```

## Uninstallation

To completely remove Drone CI:

1. Stop and remove the containers:
   ```bash
   make droneci-stop
   ```

2. Remove data directories:
   ```bash
   sudo rm -rf /opt/agency_stack/clients/{CLIENT_ID}/droneci_data
   sudo rm -rf /opt/agency_stack/docker/droneci
   ```

3. Remove from installed components:
   ```bash
   sudo sed -i '/droneci/d' /opt/agency_stack/installed_components.txt
   ```

4. Remove Traefik configuration:
   ```bash
   sudo rm /opt/agency_stack/traefik/config/dynamic/droneci-{CLIENT_ID}.toml
   ```

## Troubleshooting

### Authentication Issues

If you're having trouble authenticating:

1. Check your Gitea or Keycloak integration settings
2. Verify that the OAuth redirect URI is correct
3. Check the Drone CI logs for auth-related errors:
   ```bash
   make droneci-logs | grep -i auth
   ```

### Runner Connection Issues

If runners aren't connecting to the server:

1. Verify that the RPC secret matches between server and runner
2. Check that the runner can reach the server at the specified RPC host
3. Check runner logs for connection issues:
   ```bash
   make droneci-runner-logs | grep -i "rpc"
   ```

### Pipeline Failures

For failing pipelines:

1. Check the specific pipeline logs in the Drone CI web interface
2. Verify that pipeline steps have access to required resources
3. Check the runner logs for execution errors:
   ```bash
   make droneci-runner-logs | grep -i "error"
   ```

## Integration with Other Components

### Gitea

Drone CI can integrate with Gitea to provide repository access and webhook triggers. This integration allows for a complete DevOps workflow where code changes in Gitea automatically trigger pipeline runs in Drone CI.

### Keycloak

Integration with Keycloak provides secure single sign-on (SSO) capabilities. This is enabled with the `--enable-sso` flag during installation.

### Prometheus & Grafana

Monitoring is enabled via the Prometheus integration. Metrics are available at the `/metrics` endpoint and are automatically scraped by the Prometheus instance.

### Traefik

Drone CI is configured to work with Traefik for routing and TLS termination. This provides secure HTTPS access to your Drone CI instance.

## Further Resources

* [Official Drone CI Documentation](https://docs.drone.io/)
* [Drone CI GitHub Repository](https://github.com/harness/drone)
* [Drone Runner Documentation](https://docs.drone.io/runner/overview/)
* [Pipeline Configuration Reference](https://docs.drone.io/pipeline/overview/)
* [Drone CI Plugin Hub](https://plugins.drone.io/)
